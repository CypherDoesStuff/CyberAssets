@tool
extends Button

@export var unpressedIcon : Texture2D
@export var pressedIcon : Texture2D

func _ready() -> void:
	updateIcon()
	pressed.connect(updateIcon)
	pass

func updateIcon():
	if button_pressed:
		icon = pressedIcon
	else:
		icon = unpressedIcon
	pass