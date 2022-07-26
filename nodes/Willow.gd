extends Sprite



var target # Willow will float towards this

onready var anim = $AnimationPlayer

export var float_speed = 4
export(NodePath) var target_path # The node that will be set to target


func _ready():
	target = get_node(target_path) # Woah fingers crossed


func _physics_process(delta):
	position = lerp( self.position, target.tar_pos, float_speed * delta )


#func _on_AnimationPlayer_animation_finished(anim_name):
#	anim.play("Float")
