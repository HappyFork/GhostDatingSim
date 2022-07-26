extends Node2D


var tar_pos = global_position


func _physics_process(delta):
	tar_pos = $WillowTarget.global_position
