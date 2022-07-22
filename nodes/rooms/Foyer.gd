extends Node2D


onready var player = $YSort/Player
onready var reader = $Reader

onready var play_cam = $YSort/Player/Camera2D

onready var ysort = $YSort
onready var upperlayer = $YSort/Upper

onready var room_willow = $YSort/Position2D
onready var room_willow_anim = $YSort/Position2D/Willow/AnimationPlayer


var ground = true



func _ready():
#	player.turn( Vector2.UP, player.up_sprite )
	play_cam.current = true
	reader.start( "res://readerfiles/foyer_start.json", "001" )
	$YSort/Player/Willow/AnimationPlayer.connect("animation_finished", self, "_on_AnimationPlayer_animation_finished")


func _physics_process(delta):
	if Input.is_action_just_pressed("ui_focus_next"):
		change_floor()



func change_floor():
	if ground:
		ysort.remove_child(upperlayer)
		add_child(upperlayer)
		move_child(upperlayer, 1)
		player.change_collision_mask(2)
		ground = false
	else:
		remove_child(upperlayer)
		ysort.add_child(upperlayer)
		ysort.move_child(upperlayer, 1)
		player.change_collision_mask(1)
		ground = true



func _on_KinematicBody2D_changed_floor():
	change_floor()


func _on_Reader_foyer_willow_entered():
	room_willow_anim.play("FadeIn")

func _on_Reader_foyer_willow_snapped():
	room_willow_anim.play("FadeOut")

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "FadeIn":
		reader._on_Timer_timeout() # Maybe I should rename that function. Maybe unwait()
	elif anim_name == "FadeOut":
		room_willow.queue_free()
		Global.foyer_willow_joined = true
		player.activate_willow()



