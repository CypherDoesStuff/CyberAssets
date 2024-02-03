@tool
extends Control

@export var texButton : TextureButton
@export var titleButton : Button
@export var authorButton : LinkButton
@export var typeButton : LinkButton
@export var licenseLabel : Label
@export var supportLabel : Label
@export var favoriteButton : Button
@export var downloadButton : Button

var assetId
var assetTitle
var assetType
var assetTypeId
var assetAuthor
var assetIconUrl
var assetLicense

var assetLibrary
var displayAsFavourite

func setup(assetData, assetLib, asFavorite = false):
	assetId = assetData["asset_id"]
	assetTitle = assetData["title"]
	assetType = assetData["category"]
	assetTypeId = int(assetData["category_id"])
	assetAuthor = assetData["author"]
	assetIconUrl = assetData["icon_url"]
	assetLicense = assetData["cost"]

	titleButton.text = assetTitle
	typeButton.text = assetType
	authorButton.text = assetAuthor
	licenseLabel.text = assetLicense

	assetLibrary = assetLib
	assetLibrary.request_image(assetIconUrl, Callable(self, "recieve_texture"))

	update_favorited()

	titleButton.pressed.connect(on_click)
	typeButton.pressed.connect(on_type_filter)
	authorButton.pressed.connect(on_name_filter)
	favoriteButton.pressed.connect(on_favourite)
	downloadButton.pressed.connect(install)

	downloadButton.visible = asFavorite
	displayAsFavourite = asFavorite

	pass

func recieve_texture(texture : Texture2D):
	texButton.texture_normal = texture

func update_favorited():
	favoriteButton.set_pressed_no_signal(assetLibrary.favorites.has(assetId))
	favoriteButton.updateIcon()

func install():
	assetLibrary.install_id(assetId)

func on_click():
	assetLibrary.set_preview_asset(assetId)
	pass

func on_type_filter():
	if !displayAsFavourite:
		assetLibrary.set_search_category(assetTypeId)

func on_name_filter():
	if !displayAsFavourite:
		assetLibrary.set_search_filter(assetAuthor)

func on_favourite():
	if favoriteButton.button_pressed:
		assetLibrary.add_favorite(assetId, assetTitle, assetType, assetAuthor, assetLicense, assetIconUrl)
	else:
		assetLibrary.remove_favorite(assetId)
	pass