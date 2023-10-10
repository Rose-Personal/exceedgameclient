extends Control

signal start_game(player_char_index, opponent_char_index)
signal start_remote_game(data)

@onready var player_select : OptionButton = $PlayerChooser/Margin/VBox/PlayerCharSelect
@onready var opponent_select : OptionButton = $OpponentChooser/Margin/VBox/OpponentCharSelect

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkManager.connect("connected_to_server", _on_connected)
	NetworkManager.connect("game_started", _on_remote_game_started)
	$MenuList/CancelButton.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_start_button_pressed():
	start_game.emit(player_select.selected, opponent_select.selected)

func _on_quit_button_pressed():
	get_tree().quit()

func _on_connected(player_name):
	$MenuList/JoinButton.disabled = false
	$PlayerNameBox.editable = true
	$PlayerNameBox.text = player_name

func _on_remote_game_started(data):
	start_remote_game.emit(data)

func _on_join_button_pressed():
	var player_name = $PlayerNameBox.text
	var room_name = $RoomNameBox.text
	NetworkManager.join_room(player_name, room_name, player_select.selected)
	$MenuList/StartButton.disabled = true
	$MenuList/JoinButton.visible = false
	$MenuList/CancelButton.visible = true

func _on_cancel_button_pressed():
	NetworkManager.leave_room()
	$MenuList/StartButton.disabled = false
	$MenuList/JoinButton.visibile = true
	$MenuList/CancelButton.visible = false
