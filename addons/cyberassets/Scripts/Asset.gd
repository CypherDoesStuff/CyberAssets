@tool
extends Control

@export var texButton : TextureButton
@export var nameButton : Button
@export var authorButton : LinkButton
@export var typeButton : Button
@export var licenseLabel : Label
@export var supportLabel : Label
@export var favoriteButton : Button

var assetId
var assetName
var assetAuthor
var assetIconUrl

var assetLibrary

func setup(id, name, author, iconUrl, assetLib):
	assetId = id
	assetName = name
	assetAuthor = author
	assetIconUrl = iconUrl

	nameButton.text = assetName
	authorButton.text = assetAuthor

	assetLibrary = assetLib
	assetLibrary.request_image(assetIconUrl, Callable(self, "recieve_texture"))

	if assetLibrary.favorites.has(assetId):
		favoriteButton.set_pressed_no_signal(true)
		favoriteButton.updateIcon()

	nameButton.pressed.connect(on_click)
	favoriteButton.pressed.connect(on_favourite)
	pass

func recieve_texture(texture : Texture2D):
	texButton.texture_normal = texture

func on_click():
	#OS.shell_open("https://godotengine.org/asset-library/asset/{assetId}".format({"assetId":assetId}))
	assetLibrary.set_install_preview(assetId)
	pass

func on_favourite():
	if favoriteButton.button_pressed:
		assetLibrary.add_favorite(assetId, assetName, assetAuthor, assetIconUrl)
	else:
		assetLibrary.remove_favorite(assetId)
	pass