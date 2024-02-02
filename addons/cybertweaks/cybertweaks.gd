@tool
extends EditorPlugin

var scriptButton : Button
var assetLibButton : Button

func _enter_tree() -> void:
	scriptButton = EditorInterface.get_base_control().get_node("@VBoxContainer@14/@EditorTitleBar@15/@HBoxContainer@4053/Script")
	assetLibButton = EditorInterface.get_base_control().get_node("@VBoxContainer@14/@EditorTitleBar@15/@HBoxContainer@4053/AssetLib")
	
	#TODO ADD OPTIONS AND COMPAT FOR CYBERADDONS TWEAKS

	# Toggle editor visibility
	scriptButton.visible = false
	if !EditorInterface.is_plugin_enabled("cyberassets"):
		assetLibButton.visible = false

	# Rename assetLib tab to assets
	assetLibButton.name = "Assets"

	pass


func _exit_tree() -> void:
	# Cleanup

	scriptButton.visible = true
	if !EditorInterface.is_plugin_enabled("cyberassets"):
		assetLibButton.visible = true

	assetLibButton.name = "AssetLib"

	pass
