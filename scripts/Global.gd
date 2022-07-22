extends Node


### --- Variables --- ###

var porch_gate_checked = 0
var porch_door_checked = false
var porch_pot_checked = false
var foyer_willow_joined = false

var inv = []


### --- Custom functions --- ###

# You know, I could just as easily put all this logic in the reader script.
func set_var( variable, value ):
	if typeof( value ) == TYPE_BOOL:
		match variable:
			"porch_door_checked":
				porch_door_checked = value
			"porch_pot_checked":
				porch_pot_checked = value
	elif typeof( value ) == TYPE_INT or typeof( value ) == TYPE_REAL:
		match variable:
			"porch_gate_checked":
				porch_gate_checked += value


func set_inv( variable, action ):
	if action == "add":
		if !inv.has( variable ):
			inv.append( variable )
	elif action == "remove":
		if inv.has( variable ):
			inv.erase( variable )


func change_room( room ):
	match room:
		"foyer":
			get_tree().change_scene("res://nodes/rooms/Foyer.tscn")
		"bad_end":
			get_tree().change_scene("res://nodes/rooms/BadEnd.tscn")
