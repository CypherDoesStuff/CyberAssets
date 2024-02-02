@tool
extends Node

@export_category("Asset Lib")

@export_group("Search")
@export var assetPageParent : Control
@export var assetSearchBar : LineEdit
@export var assetImportButton : Button
@export var assetManageButton : Button
@export var searchBlocker : Control

@export_group("Install")
@export var installIcon : TextureRect
@export var installPanelTitle : RichTextLabel
@export var installDescription : RichTextLabel
@export var installButton : Button
@export var installViewFilesButton : Button

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

var assetSupportPopup : PopupMenu
var assetFilterTimer : Timer

const assetScene = preload("res://addons/cyberassets/Scenes/Asset.tscn")
const assetDefaultUrl = "https://godotengine.org/asset-library/api"
const assetFilterSearchTime = 0.25

var assetUrl : String = assetDefaultUrl
var assetFilter : String = ""
var assetCategory : int = 0
var assetReverse : bool = false
var assetVersion : String

var assetPage : int = 0
var assetSort : String
var assetSupport : Array = [1,1,0]

var useThreads : bool
var availableUrls : Dictionary 

var imageQueue : Dictionary = {}
var imageQueueLastID : int = 0

var favorites : Dictionary

var installPreviewId : String
var installDownloadUrl : String
var installPreviewUrl : String

func _ready() -> void:
	# Engine settings
	assetVersion = str(Engine.get_version_info()["major"], ".", Engine.get_version_info()["minor"])
	useThreads = EditorInterface.get_editor_settings().get_setting("asset_library/use_threads")
	availableUrls = EditorInterface.get_editor_settings().get_setting("asset_library/available_urls")

	# Load Favorites
	load_favorites()

	# Additional ui setup
	searchBlocker.visible = false

	assetSearchBar.right_icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")

	assetSiteOptions.clear()
	for key in availableUrls:
		assetSiteOptions.add_item(key)

	# Signal hookups
	assetSearchBar.text_changed.connect(_on_asset_search)
	assetSortOptions.item_selected.connect(_on_asset_sort)
	assetCategoryOptions.item_selected.connect(_on_asset_category)
	assetSiteOptions.item_selected.connect(_on_asset_site)
	assetManageButton.pressed.connect(_manage_plugins)

	assetSupportPopup = assetSupportMenu.get_popup()
	assetSupportPopup.id_pressed.connect(_on_asset_support)

	pageSelectTop.connect("_page_selected", _on_asset_page)
	pageSelectBottom.connect("_page_selected", _on_asset_page)

	installButton.pressed.connect(_install_asset)
	installViewFilesButton.pressed.connect(_open_install_file_url)

	# Timer for filter, so pressing enter isn't needed
	assetFilterTimer = Timer.new()
	assetFilterTimer.one_shot = true
	add_child(assetFilterTimer)

	assetFilterTimer.timeout.connect(search_asset_page)

	var urlKey :String = assetSiteOptions.get_item_text(0)
	assetUrl = availableUrls[urlKey]

	search_asset_page()
	pass

func search_asset_page():
	var category := ""
	if assetCategory != 0:
		category = str(assetCategory)

	searchBlocker.visible = true
	request_assets(assetPage, assetFilter, category, assetVersion, assetSort, assetReverse, assetSupport)
	pass

func set_install_preview(id):
	if(installPreviewId == id):
		return

	installPreviewId = id

	apiRequest.cancel_request()
	apiRequest.request(assetUrl.path_join(str("asset/", id)))

	searchBlocker.visible = true

	var result = await apiRequest.request_completed
	if result[0] == OK:
		var responseData = result[3].get_string_from_utf8()
		var json : JSON = JSON.new()
		var error : int = json.parse(responseData)
		if error == OK:
			installPanelTitle.text = json.data["title"]
			installDescription.text = json.data["description"]
			installPreviewUrl = json.data["browse_url"]
			installDownloadUrl = json.data["download_url"]
			request_image(json.data["icon_url"], set_install_preview_icon)
		pass

	searchBlocker.visible = false

	pass

func set_install_preview_icon(texture : Texture2D):
	installIcon.texture = texture

func download():
	if !installDownloadUrl.is_empty():
		#blah blah download
		print("downloading!")
		downloadRequest.cancel_request()

		var assetPath = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("tmp_asset_", installPreviewId, ".zip"))
		downloadRequest.download_file = assetPath
		downloadRequest.request(installDownloadUrl)

		var result = await downloadRequest.request_completed

		if result[0] == OK:
			install_from_zip(assetPath)
		pass
	pass

func install_from_zip(path : String):
	var reader = ZIPReader.new()
	var error = reader.open(path)

	if error == OK:
		print("Yoinked Asset!")
		print(reader.get_files())
		
	else:
		printerr("CyberAsset: Failed to download asset")

	reader.close()

func install():
	if !installDownloadUrl.is_empty():
		print("installing!")
		download()
		pass
	pass

#region UISignals
func _on_asset_search(filter : String):
	assetFilter = filter
	assetPage = 0
	assetFilterTimer.start(assetFilterSearchTime)
	pass

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
	assetUrl = availableUrls[key]
	search_asset_page()

func _on_asset_page(page : int):
	assetPage = page

	#update page select nodes... keep false so no resursive
	pageSelectTop.set_page(page, false)
	pageSelectBottom.set_page(page, false)

	search_asset_page()

func _open_install_file_url():
	if !installPreviewUrl.is_empty():
		OS.shell_open(installPreviewUrl)

func _install_asset():
	install()

func _manage_plugins():
	#sneak in there and open up that settings window
	var projectSettings = EditorInterface.get_base_control().get_node("/root/@EditorNode@17164/@Panel@13/@ProjectSettingsEditor@2246")
	projectSettings.popup_centered()
	projectSettings.get_node("@TabContainer@905").current_tab = 5
	pass
#endregion

#region AssetLoading
func request_assets(page: int, filter : String = "", category : String = "", version : String = "4", sort : String = "updated", reverse : bool = false, support: Array = [true,true,false]) -> void:	
	var requestUrl := assetUrl.path_join("asset?page={page}&filter={fil}&category={cat}&godot_version={ver}&cost=&sort={sort}").format(
	{
		"page":page,
		"fil":filter,
		"cat":category,
		"ver":version,
		"sort":sort,
	})

	if support[0]:
		requestUrl = str(requestUrl, "&support[official]=1")
	if support[1]:
		requestUrl = str(requestUrl, "&support[community]=1")
	if support[2]:
		requestUrl = str(requestUrl, "&support[testing]=1")

	if reverse:
		requestUrl = str(requestUrl, "&reverse")

	apiRequest.cancel_request()
	apiRequest.request(requestUrl, ["User-Agent: CyberAssets", "Accept: application/vnd.github.v3+json"], HTTPClient.METHOD_GET, "")

	var result : Array = await apiRequest.request_completed
	searchBlocker.visible = false

	if result[0] == OK:
		var responseData : String = result[3].get_string_from_utf8()
		var json : JSON = JSON.new()
		var error : int = json.parse(responseData)

		var assets : Array = json.data["result"]

		# Go ahead and start showing the page!
		if error == OK:	
			var resultMaxPage : int = json.data["pages"]
			
			pageSelectTop.maxPage = resultMaxPage
			pageSelectBottom.maxPage = resultMaxPage

			pageSelectTop.set_page(assetPage, false)
			pageSelectBottom.set_page(assetPage, false)

			setup_page(assets)
			pass
		else:
			printerr("CyberAsset: Failed to parse asset lib response! Something went wrong...")
		pass
	pass

func setup_page(assets : Array):
	#TEMP, start reusing
	for asset in assetPageParent.get_children():
		asset.queue_free()

	for assetData in assets:
		var asset = assetScene.instantiate()

		assetPageParent.add_child(asset)
		asset.setup(assetData["asset_id"], assetData["title"], assetData["author"], assetData["icon_url"], self)
	pass

func load_texture_from_buffer(buffer : PackedByteArray) -> Texture2D:
	var image := Image.new()

	var png_signature = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	var jpg_signature = PackedByteArray([255, 216, 255])
	var webp_signature = PackedByteArray([82, 73, 70, 70])
	var bmp_signature = PackedByteArray([66, 77])
		
	var load_err = ERR_PARAMETER_RANGE_ERROR
	if png_signature == buffer.slice(0, 8):
		load_err = image.load_png_from_buffer(buffer)
	elif jpg_signature == buffer.slice(0, 3):
		load_err = image.load_jpg_from_buffer(buffer)
	elif webp_signature == buffer.slice(0, 4):
		load_err = image.load_webp_from_buffer(buffer)
	elif bmp_signature == buffer.slice(0, 2):
		load_err = image.load_bmp_from_buffer(buffer)
	else:
		load_err = image.load_svg_from_buffer(buffer)

	if load_err == OK:
		return ImageTexture.create_from_image(image)
	else:
		return null
#endregion

#region AssetImageCache

func request_image(url : String, onRecieved : Callable):
	var iReq : imageRequest = imageRequest.new()
	iReq.url = url.strip_edges()
	iReq.active = false
	iReq.request = HTTPRequest.new()
	iReq.request.use_threads = useThreads
	iReq.onComplete = onRecieved
	iReq.id = imageQueueLastID
	imageQueueLastID += 1 

	add_child(iReq.request)

	iReq.request.request_completed.connect(image_request_complete.bind(iReq.id))
	imageQueue[iReq.id] = iReq

	image_update(true, false, [], iReq.id)
	update_image_queue()
	pass

func image_request_complete(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, id : int):
	if !imageQueue.has(id): push_error(ERR_PARAMETER_RANGE_ERROR)
	
	if result == HTTPRequest.RESULT_SUCCESS && response_code < HTTPClient.RESPONSE_BAD_REQUEST:
		if response_code != HTTPClient.RESPONSE_NOT_MODIFIED:
			for i in headers.size():
				if headers[i].findn("ETag:") == 0:
					var cacheFilename : String = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("assetimage_", imageQueue[id].url.md5_text()))
					var newEtag : String = headers[i].substr(headers[i].find(":") + 1, headers[i].length()).strip_edges()
					var file := FileAccess.open(str(cacheFilename + ".etag"), FileAccess.WRITE)
					if file:
						file.store_line(newEtag)

					file = FileAccess.open(str(cacheFilename + ".data"), FileAccess.WRITE)
					if file:
						file.store_32(body.size())
						file.store_buffer(body)
	
		image_update(response_code == HTTPClient.RESPONSE_NOT_MODIFIED, true, body, id)
	
	imageQueue[id].request.queue_free()
	imageQueue.erase(id)

	update_image_queue()


func image_update(useCache : bool, final : bool, data : PackedByteArray, id : int):
	#check cache for file data, if data, load

	var imageSet : bool
	var imageData : PackedByteArray = data

	if useCache:
		var cacheFilename : String = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("assetimage_", imageQueue[id].url.md5_text()))

		var file := FileAccess.open(str(cacheFilename, ".data"), FileAccess.READ)
		if file:
			var len := file.get_32()
			imageData = file.get_buffer(len)
		pass

	var image := Image.new()

	var png_signature = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	var jpg_signature = PackedByteArray([255, 216, 255])
	var webp_signature = PackedByteArray([82, 73, 70, 70])
	var bmp_signature = PackedByteArray([66, 77])
		
	var load_err = ERR_PARAMETER_RANGE_ERROR
	if png_signature == imageData.slice(0, 8):
		load_err = image.load_png_from_buffer(imageData)
	elif jpg_signature == imageData.slice(0, 3):
		load_err = image.load_jpg_from_buffer(imageData)
	elif webp_signature == imageData.slice(0, 4):
		load_err = image.load_webp_from_buffer(imageData)
	elif bmp_signature == imageData.slice(0, 2):
		load_err = image.load_bmp_from_buffer(imageData)

	var requestObject = imageQueue[id].onComplete.get_object()
	if load_err == OK && !image.is_empty() && requestObject && !requestObject.is_queued_for_deletion():
		var imgTexture := ImageTexture.create_from_image(image)
		imageQueue[id].onComplete.call(imgTexture)
		imageSet = true

	pass

func update_image_queue():	
	#update image cache if nessesary
	const maxImages : int = 6
	var currentImages : int = 0

	var toDelete : Array
	for reqId in imageQueue:
		var iReq : imageRequest = imageQueue[reqId] 
		if !iReq.active && currentImages < maxImages:
			var cacheFilename : String = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("assetimage_", iReq.url.md5_text()))
			var headers : PackedStringArray

			if FileAccess.file_exists(str(cacheFilename, ".etag")) && FileAccess.file_exists(str(cacheFilename, ".data")):
				var file : FileAccess = FileAccess.open(str(cacheFilename, ".etag"), FileAccess.READ)
				if file:
					headers.push_back(str("If-None-Match: ", file.get_line()))

			var error = iReq.request.request(iReq.url, headers)
			if error != OK:
				toDelete.push_back(reqId)
			else:
				iReq.active = true
			currentImages += 1
		elif iReq.active:
			currentImages += 1

	while toDelete.size():
		imageQueue[toDelete.front()].request.queue_free()
		imageQueue.erase(toDelete.pop_front())

class imageRequest:
	var url : String
	var id : int
	var request : HTTPRequest
	var active : bool
	var onComplete : Callable

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
		var asset = assetScene.instantiate()

		favouritePageParent.add_child(asset)
		asset.setup(key, data["title"], data["author"], data["icon_url"], self)

func add_favorite(id, name, author, url):
	var data = {"title" : name, "author" : author, "icon_url" : url}
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