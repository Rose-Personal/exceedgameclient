class_name ActionMenu
extends PanelContainer

signal choice_selected(choice_index : int)
signal ultra_force_toggled(new_value : bool)
signal discard_ex_first_toggled(new_value : bool)
signal free_force_toggled(new_value : bool)
signal number_picker_updated(new_value : int)

@onready var instructions_label : RichTextLabel = $OuterMargin/MainVBox/PanelContainer/InstructionHBox/InstructionsLabel
@onready var show_image : TextureRect = $OuterMargin/MainVBox/PanelContainer/ShowHideHBox/MarginContainer/MarginContainer/ShowImage
@onready var hide_image : TextureRect = $OuterMargin/MainVBox/PanelContainer/ShowHideHBox/MarginContainer/MarginContainer/HideImage
@onready var choice_buttons_grid : GridContainer = $OuterMargin/MainVBox/ChoiceButtons
@onready var number_panel : PanelContainer = $OuterMargin/MainVBox/NumberSelectionPanel
@onready var number_panel_label : Label = $OuterMargin/MainVBox/NumberSelectionPanel/Hbox/NumberLabel

var showing = true
var number_panel_current_number : int = 0
var number_panel_max : int = 0
var number_panel_min : int = 0

func set_choices(instructions_text : String,
		choices : Array,
		ultra_force_toggle : bool,
		number_picker_min : int,
		number_picker_max : int,
		ex_discard_order_toggle : bool,
		free_force_toggle : bool,
		no_number_picker_update : bool):
	$OuterMargin/MainVBox/CheckHBox/UltrasForceOptionCheck.visible = ultra_force_toggle
	$OuterMargin/MainVBox/CheckHBox2/ExDiscardOrderCheck.visible = ex_discard_order_toggle
	$OuterMargin/MainVBox/CheckHBox3/FreeForceOptionCheck.visible = free_force_toggle
	var col_count = 1
	if choices.size() > 5:
		col_count = 3
	elif choices.size() > 3:
		col_count = 2
	choice_buttons_grid.columns = col_count

	instructions_label.text = "[center]%s[/center]" % instructions_text
	var choice_containers = choice_buttons_grid.get_children()
	var total_choices = choices.size()
	for i in range(choice_containers.size()):
		var container = choice_containers[i]
		var button = container.get_child(0)
		var label = container.get_child(1).get_child(0)

		if i < total_choices:
			container.visible = true
			button.disabled = 'disabled' in choices[i] and choices[i].disabled
			if button.disabled:
				label.modulate = Color("757575")
			else:
				label.modulate = Color("ffffff")
			label.text = "[center]%s[/center]" % choices[i].text
		else:
			button.disabled = true
			container.visible = false
	reset_size()

	if number_picker_min != -1 and number_picker_max != -1:
		if not no_number_picker_update:
			number_panel_current_number = 0
		number_panel_min = number_picker_min
		number_panel_max = number_picker_max
		number_panel.visible = true
		number_panel_label.text = str(number_panel_current_number)
	else:
		number_panel.visible = false

func _on_choice_pressed(num : int):
	visible = false
	choice_selected.emit(num)

func _on_show_hide_button_pressed():
	showing = not showing
	show_image.visible = not showing
	hide_image.visible = showing
	choice_buttons_grid.visible = showing

func set_force_ultra_toggle(value):
	$OuterMargin/MainVBox/CheckHBox/UltrasForceOptionCheck.button_pressed = value

func set_discard_ex_first_toggle(value):
	$OuterMargin/MainVBox/CheckHBox2/ExDiscardOrderCheck.button_pressed = value

func set_free_force_toggle(value):
	$OuterMargin/MainVBox/CheckHBox3/FreeForceOptionCheck.button_pressed = value

func _on_ultras_force_option_check_toggled(button_pressed):
	ultra_force_toggled.emit(button_pressed)

func get_current_number_picker_value():
	return number_panel_current_number

func _on_number_picker_update():
	number_panel_current_number = max(number_panel_current_number, number_panel_min)
	number_panel_current_number = min(number_panel_current_number, number_panel_max)
	number_panel_label.text = str(number_panel_current_number)
	number_picker_updated.emit(number_panel_current_number)

func _on_minus_button_pressed():
	number_panel_current_number -= 1
	_on_number_picker_update()

func _on_plus_button_pressed():
	number_panel_current_number += 1
	_on_number_picker_update()

func _on_ex_discard_order_check_toggled(button_pressed):
	discard_ex_first_toggled.emit(button_pressed)

func _on_free_force_check_toggled(button_pressed):
	free_force_toggled.emit(button_pressed)
