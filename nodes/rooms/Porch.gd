extends Node2D


onready var player = $Player
onready var reader = $Reader
onready var play_cam = $Player/Camera2D
onready var room_cam = $StartCamera


func _ready():
	reader.start( "res://readerfiles/porch_start.json", "001" )


func _physics_process(delta):
	if Input.is_action_pressed("move_down"):
		$Debug/Down.show()
	else:
		$Debug/Down.hide()
	
	if Input.is_action_pressed("move_left"):
		$Debug/Left.show()
	else:
		$Debug/Left.hide()
	
	if Input.is_action_pressed("move_right"):
		$Debug/Right.show()
	else:
		$Debug/Right.hide()
	
	if Input.is_action_pressed("move_up"):
		$Debug/Up.show()
	else:
		$Debug/Up.hide()


func _on_Reader_camera_snapped():
	room_cam.current = false
	play_cam.current = true


func _on_Player_interacted( filepath, intername ):
	var start = "end" # Will change based on the interacted object and flag checks
	
	match intername:
		"door":
			if Global.inv.has( "porch_key" ):
				start = "006"
			else:
				if Global.porch_door_checked:
					start = "004"
				else:
					start = "001"
		
		"gate":
			if Global.porch_gate_checked == 0:
				start = "001"
			elif Global.porch_gate_checked == 1:
				start = "004"
			elif Global.porch_gate_checked > 1:
				if !Global.porch_door_checked:
					start = "013"
				else:
					if Global.inv.has( "porch_key" ):
						start = "009"
					else:
						start = "011"
		
		"pot":
			if Global.inv.has( "porch_key" ):
				start = "009"
			else:
				if Global.porch_pot_checked:
					start = "004"
				else:
					start = "001"
		
		"bushes", "windows":
			start = "001"
	
	if start != "end": # If start changed, calls the reader start function with that value
		reader.start( filepath, start )
