@tool
extends Node

@export_category("Asset Lib")

@export_group("Search")
@export var assetPageParent : Control
@export var assetSearchBar : LineEdit
@export var assetManageButton : Button
@export var assetPageScroll : ScrollContainer
@export var searchBlocker : Control

@export_group("Preview")
@export var previewPanel : Control
@export var previewIcon : TextureRect
@export var previewTitle : RichTextLabel
@export var previewDescription : RichTextLabel
@export var previewInstallButton : Button
@export var previewViewFilesButton : Button
@export var previewCloseButton : Button
@export var previewThumbnails : Control

@export_group("Install")
@export var installWindow : ConfirmationDialog
@export var installLocationWindow : FileDialog
@export var installWindowName : Label
@export var installTree : Tree
@export var installChangePathButton : Button
@export var installIgnoreAssetRoot : CheckBox
@export var installConflictsLabel : Label

@export_group("Import")
@export var importButton : Button
@export var importFileDialouge : FileDialog

@export_group("Filters")
@export var assetShowPluginsButton : Button
@export var assetSortOptions : OptionButton
@export var assetCategoryOptions : OptionButton
@export var assetSiteOptions : OptionButton
@export var assetSupportMenu : MenuButton

@export_group("Page")
@export var pageSelectTop : HBoxContainer
@export var pageSelectBottom : HBoxContainer

@export_group("Favorites")
@export var favouritePageParent : Control

@export_category("HTTP")
@export var apiRequest : HTTPRequest
@export var downloadRequest : HTTPRequest

const previewDefaultTexture = preload("res://addons/cyberassets/Icons/plugin.svg")

var assetSupportPopup : PopupMenu
var assetFilterTimer : Timer

const assetScene = preload("res://addons/cyberassets/Scenes/Asset.tscn")
const assetDefaultUrl = "https://godotengine.org/asset-library/api"
const assetFilterSearchTime = 0.25

#api
const apiScript = preload("res://addons/cyberassets/Scripts/AssetApi.gd")
const installer = preload("res://addons/cyberassets/Scripts/AssetInstaller.gd")

const installDefaultPath = "res://"

var api = apiScript.new()
var apiUrl : String = assetDefaultUrl

#filters
var assetFilter : String = ""
var assetCategory : int = 0
var assetReverse : bool = false
var assetVersion : String
var assetPage : int = 0
var assetSort : String
var assetSupport : Array = [1,1,0]

var assetPageAssets : Array = []

#preview
var previewId : String
var previewDownloadUrl : String
var previewFileUrl : String

#install
var installPath : String = installDefaultPath
var installFiles : Array
var installTreeDict : Dictionary

var initalize : bool
var useThreads : bool
var availableUrls : Dictionary 
var favorites : Dictionary

signal _on_install_window_response(isCancel)

func _ready() -> void:
	if !initalize:
		return 

	add_child(api)

	# Engine settings
	assetVersion = str(Engine.get_version_info()["major"], ".", Engine.get_version_info()["minor"])
	useThreads = EditorInterface.get_editor_settings().get_setting("asset_library/use_threads")
	availableUrls = EditorInterface.get_editor_settings().get_setting("asset_library/available_urls")

	# Load Favorites
	load_favorites()

	# Additional ui setup
	searchBlocker.visible = false
	previewPanel.visible = false

	assetSearchBar.right_icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")

	assetSiteOptions.clear()
	for key in availableUrls:
		assetSiteOptions.add_item(key)

	installWindow.set_unparent_when_invisible(true)
	installLocationWindow.set_unparent_when_invisible(true)
	importFileDialouge.set_unparent_when_invisible(true)

	remove_child(installWindow)
	remove_child(installLocationWindow)
	remove_child(importFileDialouge)

	# Signal hookups
	assetSearchBar.text_changed.connect(_on_asset_search)
	assetSortOptions.item_selected.connect(_on_asset_sort)
	assetCategoryOptions.item_selected.connect(_on_asset_category)
	assetSiteOptions.item_selected.connect(_on_asset_site)
	assetManageButton.pressed.connect(_manage_plugins)

	assetSupportPopup = assetSupportMenu.get_popup()
	assetSupportPopup.id_pressed.connect(_on_asset_support)

	importButton.pressed.connect(_import_dialouge_show)
	importFileDialouge.file_selected.connect(_import_file)

	pageSelectTop.connect("_page_selected", _on_asset_page)
	pageSelectBottom.connect("_page_selected", _on_asset_page)

	previewInstallButton.pressed.connect(_preview_install)
	previewViewFilesButton.pressed.connect(_preview_open_files)
	previewCloseButton.pressed.connect(_preview_close)

	installWindow.confirmed.connect(_install_confirm)
	installWindow.canceled.connect(_install_cancel)
	installTree.item_edited.connect(_install_tree_edited)
	installIgnoreAssetRoot.pressed.connect(_install_ignore_parent_pressed)
	installChangePathButton.pressed.connect(_install_change_path)
	installLocationWindow.dir_selected.connect(_install_set_path)

	# Timer for filter, so pressing enter isn't needed
	assetFilterTimer = Timer.new()
	assetFilterTimer.one_shot = true
	add_child(assetFilterTimer)

	assetFilterTimer.timeout.connect(search_asset_page)

	var urlKey :String = assetSiteOptions.get_item_text(0)
	apiUrl = availableUrls[urlKey]

	search_asset_page()
	pass

func _exit_tree() -> void:
	if initalize:
		installWindow.queue_free()
		installLocationWindow.queue_free()
		importFileDialouge.queue_free()

func search_asset_page():
	var category := ""
	if assetCategory != 0:
		category = str(assetCategory)

	searchBlocker.visible = true
	var libraryData = await api.request_assets(apiUrl, apiRequest, assetPage, assetFilter, category, assetVersion, assetSort, assetReverse, assetSupport)

	searchBlocker.visible = false
	if libraryData:
		var assets = libraryData["result"]
		var resultMaxPage : int = libraryData["pages"]
		
		pageSelectTop.maxPage = resultMaxPage
		pageSelectBottom.maxPage = resultMaxPage

		pageSelectTop.set_page(assetPage, false)
		pageSelectBottom.set_page(assetPage, false)

		setup_page(assets)
	pass

func setup_page(assets : Array):
	for asset in assetPageAssets:
		asset.queue_free()

	assetPageAssets.clear()

	for assetData in assets:
		var asset = assetScene.instantiate()

		assetPageAssets.push_back(asset)
		assetPageParent.add_child(asset)
		asset.setup(assetData, self)
	
	assetPageScroll.set_deferred("scroll_vertical", 0)

func request_image(assetUrl : String, onRecieved : Callable):
	api.request_image(assetUrl, useThreads, onRecieved)

func set_preview_asset(id):
	if(previewId == id):
		previewPanel.visible = true
		return

	previewIcon.texture = previewDefaultTexture
	previewId = id

	searchBlocker.visible = true
	var data = await api.request_asset_from_id(apiUrl, id, apiRequest)


	if !data.is_empty():
		previewTitle.text = data["title"]
		previewDescription.text = data["description"]
		previewFileUrl = data["browse_url"]
		previewDownloadUrl = data["download_url"]
		api.request_image(data["icon_url"], useThreads, set_preview_asset_icon)

		for preview in previewThumbnails.get_children(): preview.queue_free()
		for preview in data["previews"]:
			api.request_image(preview["thumbnail"], useThreads, add_preview_thumbnail)

	previewPanel.visible = true
	searchBlocker.visible = false

func set_preview_asset_icon(texture : Texture2D):
	previewIcon.texture = texture

func add_preview_thumbnail(texture : Texture2D):
	var thumb = TextureRect.new()
	thumb.texture = texture
	thumb.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previewThumbnails.add_child(thumb)

func install():
	if !previewDownloadUrl.is_empty():
		install_download(previewDownloadUrl, previewId)

func install_id(id : String):
	var assetData = await api.request_asset_from_id(apiUrl, id, apiRequest)
	install_download(assetData["download_url"], id)

func install_download(url : String, id : String):
	var assetPath = await installer.download(url, id, downloadRequest)
	if !assetPath.is_empty():
		installPath = installDefaultPath
		install_zip(assetPath)

func install_zip(path : String):
	installFiles = installer.get_zip_files_from_path(path)
	if installFiles.size() > 0:
		installIgnoreAssetRoot.button_pressed = true

		update_install_dialouge(installFiles, true)
		EditorInterface.popup_dialog_centered(installWindow)
	else:
		printerr("Cyber Asset: Failed to get zip files!")

	var isCanceled = await _on_install_window_response
	var installed

	if !isCanceled:
		installed = installer.install_from_zip(path, installIgnoreAssetRoot.button_pressed, install_get_file_selection(), ProjectSettings.globalize_path(installPath))

	if installed:
		EditorInterface.get_resource_filesystem().scan()
		print(str("Cyber Asset: Installed ", previewTitle.text, " Sucessfully!"))

func update_install_dialouge(assetFiles : Array, ignoreRoot : bool):
	installWindowName.text = previewTitle.text
	var conflicts = false

	installTreeDict = {}
	var installTreeItems = {}

	installTree.clear()

	var parentItem = installTree.create_item()
	parentItem.set_text(0, installPath)

	for index in assetFiles.size():
		var dir = assetFiles[index]

		var pathFull = dir.split("/", false)

		if ignoreRoot:
			pathFull.remove_at(0)

		var pathSegmentSize = pathFull.size()
		var pathSegment
		var treeItem

		if pathSegmentSize <= 0:
			continue
		elif pathSegmentSize > 1:
			pathSegment = pathFull[pathSegmentSize - 1]
			treeItem = installTree.create_item(installTreeItems[pathFull[pathSegmentSize - 2]])
		else:
			pathSegment = pathFull[0]
			treeItem = installTree.create_item(parentItem)

		var itemConflict = check_dir_or_file_exists((installPath.path_join("/".join(pathFull))))
		if itemConflict:
			conflicts = true

		treeItem.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		treeItem.set_text(0, pathSegment)
		treeItem.set_editable(0, true)
		treeItem.set_checked(0, !itemConflict)

		installTreeItems[pathSegment] = treeItem
		installTreeDict[dir] = treeItem

	installConflictsLabel.text = "No Conflicts Found"
	if conflicts:
		installConflictsLabel.text = "File Conflicts Found"


func install_get_file_selection() -> Dictionary:
	var installFileSelection : Dictionary
	for key in installTreeDict:
		installFileSelection[key] = installTreeDict[key].is_checked(0) || installTreeDict[key].is_indeterminate(0)
	return installFileSelection


func check_dir_or_file_exists(path : String) -> bool:
	if DirAccess.dir_exists_absolute(path) || FileAccess.file_exists(path): 
		return true
	
	return false

func set_search_filter(filter : String):
	assetSearchBar.text = filter
	assetFilter = filter
	assetPage = 0
	search_asset_page()

func set_search_category(category : int):
	assetCategoryOptions.selected = category
	assetCategory = category
	search_asset_page()

#region UISignals
func _on_asset_search(filter : String):
	assetFilter = filter
	assetPage = 0
	assetFilterTimer.start(assetFilterSearchTime)

func _on_asset_sort(type : int):
	#sneaky way to simplify this
	assetSort = str(["updated","updated","name","name","cost","cost"][type])
	assetReverse = [false,true,false,true,false,true][type]
	search_asset_page()

func _on_asset_category(type : int):
	assetCategory = type
	search_asset_page()

func _on_asset_support(index : int):
	#for some reason this is nessesary? Replace later if possible
	assetSupportPopup.set_item_checked(index, !assetSupportPopup.is_item_checked(index))
	assetSupport[index] = assetSupportPopup.is_item_checked(index)
	search_asset_page()

func _on_asset_site(site : int):
	var key := assetSiteOptions.get_item_text(site)
	apiUrl = availableUrls[key]
	search_asset_page()

func _on_asset_page(page : int):
	assetPage = page

	#update page select nodes... keep false so no resursive
	pageSelectTop.set_page(page, false)
	pageSelectBottom.set_page(page, false)

	search_asset_page()

func _preview_install():
	install()

func _preview_open_files():
	if !previewFileUrl.is_empty():
		OS.shell_open(previewFileUrl)

func _preview_close():
	previewPanel.visible = false

func _install_confirm():
	emit_signal("_on_install_window_response", false)

func _install_cancel():
	emit_signal("_on_install_window_response", true)

func _install_tree_edited():
	installTree.get_edited().propagate_check(0, false)

func _install_ignore_parent_pressed():
	update_install_dialouge(installFiles, installIgnoreAssetRoot.button_pressed)

func _install_change_path():
	EditorInterface.popup_dialog_centered(installLocationWindow)

func _install_set_path(dir : String):
	installPath = dir
	print(installPath)

func _manage_plugins():
	#sneak in there and open up that settings window
	var projectSettings = EditorInterface.get_base_control().get_node("/root/@EditorNode@17164/@Panel@13/@ProjectSettingsEditor@2246")
	projectSettings.popup_centered()
	projectSettings.get_node("@TabContainer@905").current_tab = 5

func _import_dialouge_show():
	EditorInterface.popup_dialog_centered(importFileDialouge)

func _import_file(dir : String):
	install_zip(dir)
#endregion

#region Favorites
func load_favorites():
	var file := FileAccess.open(EditorInterface.get_editor_paths().get_config_dir().path_join("favorites.tres"), FileAccess.READ)
	if file:
		var text := file.get_as_text()
		favorites = JSON.parse_string(text)

	if !favorites:
		favorites = {}

	setup_favorites()

func setup_favorites():
	for child in favouritePageParent.get_children(): child.queue_free()

	for key in favorites:
		var data = favorites[key]
		data["asset_id"] = key
		data["category_id"] = -1

		var asset = assetScene.instantiate()

		favouritePageParent.add_child(asset)
		asset.setup(data, self, true)
	
	for asset in assetPageAssets:
		asset.update_favorited()

func add_favorite(id, name, type, author, license, url):
	var data = {"title" : name, "category" : type, "author" : author, "cost" : license, "icon_url" : url}
	favorites[id] = data
	save_favorites()

func remove_favorite(id):
	favorites.erase(id)
	save_favorites()

func save_favorites():
	if favorites:
		var file := FileAccess.open(EditorInterface.get_editor_paths().get_config_dir().path_join("favorites.tres"), FileAccess.WRITE)
		if file:
			file.store_line(JSON.stringify(favorites))
	
	setup_favorites()

#endregion