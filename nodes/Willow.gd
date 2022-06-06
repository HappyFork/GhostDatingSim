extends Sprite



onready var anim = $AnimationPlayer



func _on_AnimationPlayer_animation_finished(anim_name):
	anim.play("Float")
