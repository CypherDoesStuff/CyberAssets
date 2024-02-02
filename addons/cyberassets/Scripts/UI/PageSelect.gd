@tool
extends HBoxContainer

@export var minPage : int = 0
@export var maxPage : int = 100

@export var maxPageButtonCount : int

var page : int

var firstButton
var previousButton
var nextButton
var lastButton
var pageButtonContainer

signal _page_selected(page : int)

func _enter_tree() -> void:
	#todo move to method, so we can update when maxPage is set

	page = minPage

	firstButton = Button.new()
	firstButton.text = "First"
	firstButton.pressed.connect(first_page)

	previousButton = Button.new()
	previousButton.text = "Previous"
	previousButton.pressed.connect(previous_page)
	
	nextButton = Button.new()
	nextButton.text = "Next"
	nextButton.pressed.connect(next_page)

	lastButton = Button.new()
	lastButton.text = "Last"
	lastButton.pressed.connect(last_page)

	pageButtonContainer = HBoxContainer.new()

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND
	add_child(spacer)

	add_child(firstButton)
	add_child(previousButton)

	add_child(VSeparator.new())

	add_child(pageButtonContainer)

	add_child(VSeparator.new())

	add_child(nextButton)
	add_child(lastButton)

	spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND
	add_child(spacer)

	set_page(page, false)
	pass

func _exit_tree() -> void:
	for control in get_children():
		control.queue_free()

func set_page(value : int, emitSignal : bool = true):
	page = clamp(value, minPage, maxPage)
	setup_buttons(page)

	if emitSignal:
		_page_selected.emit(page)
	pass

func setup_buttons(currentPage : int):
	for child in pageButtonContainer.get_children(): child.queue_free()

	var pageStart : int = clamp(currentPage - (maxPageButtonCount / 2), 0, maxPage)
	var pageRange : int = pageStart + maxPageButtonCount

	for i in range(pageStart, min(maxPage, pageRange)):
		var pageButton = Button.new()

		pageButton.text = str(" ", i + 1, "")
		pageButton.custom_minimum_size.x = 40
		pageButton.pressed.connect(set_page.bind(i))

		if i == currentPage: pageButton.disabled = true

		pageButtonContainer.add_child(pageButton)

	var isAtStart : bool = currentPage == 0
	var isAtEnd : bool = currentPage == maxPage - 1

	firstButton.disabled = isAtStart
	previousButton.disabled = isAtStart
	lastButton.disabled = isAtEnd
	nextButton.disabled = isAtEnd

	pass
	
func refresh():
	set_page(page, false)
		
func first_page():
	set_page(0)

func previous_page():
	set_page(page - 1)

func next_page():
	set_page(page + 1)

func last_page():
	set_page(maxPage - 1)
