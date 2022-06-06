class_name ElevatorTile

extends Area2D

export(bool) var loading_left
export(bool) var going_up

func can_move( dir ):
	if abs(dir.x) < abs(dir.y):
		return false
	else:
		return true 

func if_going_up( dir ):
	if dir.x > 0:
		if loading_left:
			return going_up
		else:
			return !going_up
	else:
		if loading_left:
			return !going_up
		else:
			return going_up
