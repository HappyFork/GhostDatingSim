extends Node2D


var rng = RandomNumberGenerator.new()
export var th_low = 10.0
export var th_high = 60.0


onready var player = $Player
onready var reader = $NewReader
onready var play_cam = $Player/Camera2D
onready var room_cam = $StartCamera
onready var thdr_sound = $ThunderPlayer
onready var thdr_timer = $ThunderTimer
onready var thdr_anim = $AnimationPlayer


func _ready():
	# Set and start the thunder timer
	rng.randomize()
	thdr_timer.wait_time = rng.randf_range( th_low/10, th_high/10 )
	thdr_timer.start()
	
	# Start the beginning cutscene
	reader.start( "res://readerfiles/porch_start.json", "001" )


func _on_Reader_porch_camera_snapped():
	room_cam.current = false
	play_cam.current = true

#Depreciated lol
#func _on_Reader_camera_snapped():
#	room_cam.current = false
#	play_cam.current = true


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


func _on_ThunderTimer_timeout():
	thdr_sound.play()
	thdr_anim.play("Thunderclap")
	thdr_timer.wait_time = rng.randf_range( th_low, th_high )
	thdr_timer.start()
	
