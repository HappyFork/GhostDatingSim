extends KinematicBody2D



### --- Variables --- ###

# Onready variables
#onready var sprite = $Sprite # Displays the current player sprite
onready var asprite = $AnimatedSprite # Displays the current sprite and plays walking animation
onready var move_timer = $Timer # Timer to control the input pause after turning and exiting dialogue
onready var tween = $Tween # Moves the player between tiles
onready var look = $RayCast2D # Checks for collision in front of the player
onready var willow_anim = $WillowImproved/FadeAnimPlayer # The version of Willow that follows the player


# Export variables
#export var up_sprite : Texture # Sprite when facing up
#export var down_sprite : Texture # Sprite when facing down
#export var left_sprite : Texture # Sprite when facing left
#export var right_sprite : Texture # Sprite when facing right
export var speed = 3.0 # How quickly the player moves between tiles


# Regular variables
var current_anim = "FrontWalk"
var tile_size = 64 # Size of the tiles. Self explanatory
var move_lock = false # When true, the player can't move
var on_elevator = null # Holds the elevator tile the player is on, if any
var change_floor_when_stopped = false # If true, will change floors when stopped


# Signals
signal interacted( filepath, intername ) # Emits when player interacts with something
signal stopped_moving # Emits when the player stops moving (for cutscene management)
signal changed_floor # Emits when the player changes floors



### --- Engine functions --- ###

# Ready function. Runs every time the player is loaded into a scene
func _ready() -> void:
	position = position.snapped( Vector2.ONE * tile_size ) # Snaps the player to the movement grid
	position += Vector2.ONE * tile_size/2 # Centers the player on the tile
	#asprite.animation = "FrontWalk"
	#asprite.frame = 0 # Should face the player down?
	#cutscene_turn( Vector2.DOWN, down_sprite ) # Player starts by facing down


# Physics process function. Runs every frame
func _physics_process(delta):
	look.force_raycast_update()
	
	if( !tween.is_active() and !move_lock ): #Don't take inputs if movement is locked or the player is moving
		if( Input.is_action_just_pressed("interact") ):
			interact()
		
		if( Input.is_action_pressed("move_up") ):
			if( look.cast_to != Vector2.UP * tile_size ):
				turn( Vector2.UP, "BackWalk" )
			else:
				check_step()
		elif( Input.is_action_pressed("move_down") ):
			if( look.cast_to != Vector2.DOWN * tile_size ):
				turn( Vector2.DOWN, "FrontWalk" )
			else:
				check_step()
		elif( Input.is_action_pressed("move_left") ):
			if( look.cast_to != Vector2.LEFT * tile_size ):
				turn( Vector2.LEFT, "LeftWalk" )
			else:
				check_step()
		elif( Input.is_action_pressed("move_right") ):
			if( look.cast_to != Vector2.RIGHT * tile_size ):
				turn( Vector2.RIGHT, "RightWalk" )
			else:
				check_step()



### --- Custom Functions --- ###

# Turn function. Turns the character
func turn( dir, anim ):
	current_anim = anim
	look.cast_to = dir * tile_size
	look.force_raycast_update()
	asprite.animation = current_anim
	asprite.frame = 0
	move_lock = true
	move_timer.start()


# Cutscene turn function. Turns the character without returning control to the player
func cutscene_turn( dir, anim ):
	current_anim = anim
	look.cast_to = dir * tile_size
	look.force_raycast_update()
	asprite.animation = current_anim
	asprite.frame = 0


# Checks to see that the player can take a step forward, and calls step if so
func check_step():
	var dest_pos = position + look.cast_to
	
	# First, if the player is on an Elevator tile, collision is irrelevant
	if on_elevator is ElevatorTile:
		if on_elevator.can_move( look.cast_to ):
			if on_elevator.if_going_up( look.cast_to ):
				dest_pos.y -= tile_size/2
			else:
				dest_pos.y += tile_size/2
				change_floor_when_stopped = true
			
			on_elevator = null
			step( dest_pos )
	
	if look.is_colliding():
		var obj = look.get_collider() # Thing raycast collided with
		
		if obj is ElevatorTile:
			if obj.can_move( look.cast_to ):
				on_elevator = obj
					
				if obj.going_up:
					dest_pos.y -= tile_size/2
					emit_signal("changed_floor")
				else:
					dest_pos.y += tile_size/2
				
				step( dest_pos )
	else:
		step( dest_pos )


# Move function. Moves the character in the direction that they're facing
func step( new_pos ):
	tween.interpolate_property( self, "position", position, new_pos, 1.0/speed, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT )
	#asprite.frame = 1
	asprite.play( current_anim )
	tween.start()


# Interact function. Gives the information from the interacted object to the dialogue box
func interact():
	if look.is_colliding():
		if look.get_collider() is Interactable:
			emit_signal( "interacted", look.get_collider().reader_file, look.get_collider().interactable_name )


## Okay, right now I don't use this function, but I don't want to lose this code
#func get_all_collisions():
#	#This code shamelessly stolen from Slsilicon on the godot forums
#	var collisions = [] #Colliding objects go here
#	var dest_pos = position + look.cast_to
#
#	look.force_raycast_update()
#	while( look.is_colliding() ):
#		var obj = look.get_collider() #Get the object that is colliding.
#		collisions.append( obj ) #add it to the array
#		look.add_exception( obj ) #add the object to the ray's exception
#		look.force_raycast_update()
#
#	for obj in collisions:
#		look.remove_exception( obj )
#
#	return collisions


# Changes the collision mask of the player and the look raycast
func change_collision_mask( mask ):
	set_collision_mask( mask )
	look.set_collision_mask( mask )


## Activate Willow.
#func activate_willow():
#	$WillowImproved.show()
#	willow_anim.play("FadeInForeground")


### --- Signal Functions --- ###

# When the move_timer ends, the player can move again
func _on_Timer_timeout():
	move_lock = false 


# When the tween ends, lets the reader know, then checks to see if player needs to switch floors.
func _on_Tween_tween_all_completed():
	asprite.stop()
	asprite.frame = 0 # Stop walking animation and go back to 0 frame
	emit_signal("stopped_moving")
	
	if change_floor_when_stopped:
		emit_signal("changed_floor")
		change_floor_when_stopped = false


# Lets the Reader lock player movement at the start of a cutscene
func _on_Reader_read_started():
	move_lock = true

# Depreciated lol
#func _on_Reader_player_movelocked():
#	move_lock = true


# Lets the player move after a reader box is closed
func _on_Reader_read_ended():
	move_timer.start() # I need to start the timer instead of just setting
	# move_lock to false otherwise the same input will start a new interaction


func _on_Reader_player_stepped():
	step(position + look.cast_to)

# Depreciated lol
#func _on_Reader_player_moved():
#	step(position + look.cast_to)


# Turns the player during cutscenes
func _on_Reader_player_turned(dir):
	match dir:
		"up":
			cutscene_turn( Vector2.UP, "BackWalk" )
		"down":
			cutscene_turn( Vector2.DOWN, "FrontWalk" )
		"left":
			cutscene_turn( Vector2.LEFT, "LeftWalk" )
		"right":
			cutscene_turn( Vector2.RIGHT, "RightWalk" )
