@tool
extends EditorPlugin

var assetLibButton : Button
var assetLibRoot : Control

var editorMainPanel : Control

const assetPanel = preload("res://addons/cyberassets/Scenes/AssetLibrary.tscn")
const asset = preload("res://addons/cyberassets/Scenes/Asset.tscn")

var assetLibInstance

func _enter_tree() -> void:
	# Grab the asset menu related ui
	assetLibButton = EditorInterface.get_base_control().find_child("AssetLib", true, false)
	assetLibRoot = EditorInterface.get_editor_main_screen().find_child("*EditorAssetLibrary*", true, false)
	
	editorMainPanel = EditorInterface.get_editor_main_screen().get_parent().get_parent()

	# Hide asset button
	assetLibButton.set_deferred("visible", false)

	# Instantiate and add custom panel
	assetLibInstance = assetPanel.instantiate()
	assetLibInstance.initalize = true
	EditorInterface.get_editor_main_screen().add_child(assetLibInstance)
	_make_visible(false)

	# Let user know were enabled
	print("Enabled Asset Lib!")
	pass

func _exit_tree() -> void:
	# Cleanup
	assetLibButton.visible = true;
	editorMainPanel.visible = true;

	if assetLibInstance:
		assetLibInstance.queue_free()

	pass

func _get_plugin_name() -> String:
	return "Assets"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("AssetLib", "EditorIcons")

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if assetLibInstance:
		assetLibInstance.visible = visible

func _show_asset_browser() -> void:
	assetLibInstance.visible = !assetLibInstance.visible
	pass
