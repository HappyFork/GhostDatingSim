extends CanvasLayer



### --- READER FILE STRUCTURE --- ###

# The json keys are 3-numeral indexes, from "001" to "999" if necessary. The
# values are their own nested key-value dictionaries. Every line will always
# have a "type" key, the value of which will tell the parser what the rest of
# the indexed dictionary contains
#
# Ex: "001" : {"type": ...
#
# Different types (and they keys they use) are:
# # "text" - "text"
# # "choice" - "text", "choice1", "choice2"
# # "room" - "target", "action"
# # "stage" - "slot", "portrait", "anim"
# # "variable" - "variable", "value"
# # "inventory" - "variable", "action"
# # "change_room" - "room"
# # "sound" - (work in progress)
# # "wait" - "time"
#
# Every line (except "choice" and "change_room" will also have a "next" key,
# indicating which index the reader will parse next. If "next": "end", the
# cutscene ends.
#
# "change_room" lines will always end a scene, so no "next" is necessary.
# The two choice keys in "choice" themselves contain dictionaries with "text"
# and "next" keys. The "next" is therefore determined by which choice the player
# chooses.


### --- Variables --- ###

# Onready variables
onready var main_box = $NinePatchRect # The main reader box
onready var main_text = $NinePatchRect/RichTextLabel # The text container in the main reader box
onready var choice1_text = $NinePatchRect/Choice1 # Text container for choice 1 text
onready var choice1_arrow = $NinePatchRect/CursorArrow1 # Arrow pointing to choice 1
onready var choice2_text = $NinePatchRect/Choice2 # Text container for choice 2 text
onready var choice2_arrow = $NinePatchRect/CursorArrow2 # Arrow pointing to choice 2
onready var sprite_slots = [ $Sprite1, $Sprite2, $Sprite3, $Sprite4 ] # The sprite slots
onready var tween = $Tween # The tween that moves the sprites
onready var wait_timer = $Timer # Timer used to wait


# Export variables
export var slide_speed = 0.25
export(int, 10) var tween_type 


# Regular variables
var dictionary : Dictionary # Holds the loaded in reader file
var filepath = "" # The .json filepath to the reader file
var choice_select = 0 # The choice option currently selected. Should be 0 if the current index isn't type choice
var active_sprite = 0 # Which of the sprites is not greyed out. Should be 0 if there are no sprites loaded
var index # The index of the reader dictionary that is currently displayed
var wait = false


# Signals
signal read_ended # Emitted when the reader closes, returning control to the player
signal player_movelocked # Emitted at the start of a cutscene, prevents player from taking inputs

# Signals that "room" lines emit
signal player_turned( dir )
signal player_moved # Probably should be "player_stepped" to be consistent but changing it isn't worth the hassle
signal camera_snapped
signal foyer_willow_entered



### --- Engine functions --- ###

# Runs when there is an input event
func _input(event):
	# Only does anything when there's a dictionary loaded in
	if( dictionary.size() > 0 ):
		# If the input event is the player pressing interact
		if( event.is_action_pressed("interact") ):
			# If the current index is type choice
			if dictionary[index]["type"] == "choice":
				# Set the next index based on which choice is currently selected
				match  choice_select:
					1:
						index = dictionary[index]["choice1"]["next"]
					2:
						index = dictionary[index]["choice2"]["next"]
				
				# And then clear the choice elements from the reader
				clear_choice()
			# If the current index is any other type besides choice
			else:
				# Just set the next index to "next"
				index = dictionary[index]["next"]
			
			parse_index()
		
		# If the input even is left or right, change the selected choice
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
			if dictionary[index]["type"] == "choice":
				if choice_select == 1:
					choice1_arrow.hide()
					choice2_arrow.show()
					choice_select = 2
				elif choice_select == 2:
					choice1_arrow.show()
					choice2_arrow.hide()
					choice_select = 1



### --- Custom functions --- ###

# Starts the reader event using the passed in script on the passed in index
func start(fp, start):
	emit_signal("player_movelocked")
	filepath = fp
	index = start
	dictionary = load_reader_file( filepath )
	parse_index()


# Loads the dictionary with the .json file passed in by the interactable
func load_reader_file( fp ) -> Dictionary:
	# I don't remember where I stole this code from but I don't know how it works lol
	var file = File.new()
	assert( file.file_exists( fp ) )
	
	file.open( fp, file.READ )
	var dic = parse_json( file.get_as_text() )
	assert( dic.size() > 0 )
	return dic


# I had to set the next index and then call parse index enough times that I made
# it its own function. Maybe I'll get this function to accept an argument for
# choices or something but it's not a priority.
func next_line():
	index = dictionary[index]["next"]
	parse_index()


# Displays things based on the information at the current index in the loaded dictionary
func parse_index():
	# If index is end, end the reader and don't execute the rest of the function
	if index == "end":
		end()
		return
	
	# Types: Text, Event?, Choice, Room (anything that isn't a child of reader),
			# Stage (setting and moving sprites), Variable, ChangeRoom, Sound?
	match dictionary[index]["type"]:
		"text": # Changes the text displayed in the main text box
			main_text.text = dictionary[index]["text"]
			if( !main_box.visible ):
				main_box.show()
			
		"event": # Executes a named method (this may be superceded by room, variable, and change_room)
			pass
			
		"choice": # Allows player to choose between two options
			main_text.text = dictionary[index]["text"]
			choice1_text.text = dictionary[index]["choice1"]["text"]
			choice2_text.text = dictionary[index]["choice2"]["text"]
			choice_select = 1
			choice1_arrow.show()
			if( !main_box.visible ):
				main_box.show()
			
		"room": # Sends a signal to the current room to do something
			# Not a fan of nested match statements. There has to be a better way to do this
			match dictionary[index]["target"]:
				"player":
					match dictionary[index]["action"]:
						"turn":
							emit_signal("player_turned", dictionary[index]["direction"])
							next_line()
						"step":
							emit_signal("player_moved")
							wait = true
					
				"camera":
					if dictionary[index]["action"] == "snap":
						emit_signal("camera_snapped")
						next_line()
				"foyer":
					print("ran")
					if dictionary[index]["action"] == "willow_enter":
						emit_signal("foyer_willow_entered")
						wait = true
		
		"stage": # Changes the portraits displayed above the reader box
			var tex = load( "res://assets/portraits/" + dictionary[index]["portrait"] + ".png" ) # I'm not a fan of this. I should preload these portraits probably.
			var sp_sl = sprite_slots[ dictionary[index]["slot"] - 1 ]
			var side
			
			# This function is bwoken :( Fix it sober casey
			if dictionary[index]["slot"] > 2:
				side = $RightOffscreen.position
			else:
				side = $LeftOffscreen.position
			
			
			match dictionary[index]["anim"]:
				"slide_in":
					tween.interpolate_property( sp_sl, "position", side, sp_sl.position, 0.75, Tween.TRANS_EXPO, Tween.EASE_OUT )
				"float_in":
					tween.interpolate_property( sp_sl, "position", side, sp_sl.position, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT )
				"bounce_in":
					tween.interpolate_property( sp_sl, "position", side, sp_sl.position, 2.2, Tween.TRANS_ELASTIC, Tween.EASE_OUT )
				_:
					tween.remove_all()
			
			sp_sl.texture = tex
			tween.start()
			next_line()
		
		"variable": # Sets a variable in Global
			Global.call_deferred( "set_var", dictionary[index]["variable"], dictionary[index]["value"] )
			next_line()
		
		"inventory":
			Global.call_deferred( "set_inv", dictionary[index]["variable"], dictionary[index]["action"] )
			next_line()
		
		"change_room": # Changes the scene to the named room
			Global.call_deferred( "change_room", dictionary[index]["room"] )
			end() #Always ends the reader box
		
		"sound": # Plays, stops, or changes a sound
			pass
		
		"wait": # Waits a certain amount of time before going to the next line
			wait_timer.wait_time = dictionary[index]["time"]
			wait = true
			wait_timer.start()
		
		_: # Default. Runs if there is no type. This shouldn't happen.
			print( "Index " + index + " of readerfile " + filepath + " has no type!" )
			end()


# Clears the reader elements that are only used for choices
func clear_choice():
	choice1_arrow.hide()
	choice1_text.text = ""
	choice2_arrow.hide()
	choice2_text.text = ""
	choice_select = 0


# Resets all the sprites
func reset_all_sprites():
	reset_sprite( 1 )
	reset_sprite( 2 )
	reset_sprite( 3 )
	reset_sprite( 4 )
	active_sprite = 0

# Resets a specific sprite
func reset_sprite( slot ):
	sprite_slots[ slot - 1 ].texture = null


# Clears and hides all reader elements. Emits signal that reader ended
func end():
	# Empties the dictionary
	dictionary = {}
	
	# Resets the reader file
	filepath = ""
	
	# Hides the reader box and choice arrows
	main_box.hide()
	choice1_arrow.hide()
	choice2_arrow.hide()
	
	# Empties the text fields
	main_text.text = ""
	choice1_text.text = ""
	choice2_text.text = ""
	choice_select = 0
	
	# Reset the sprites
	reset_all_sprites()
	
	# Emits the reader ended signal
	emit_signal("read_ended")



### --- Signal functions --- ###

func _on_Player_stopped_moving():
	if wait:
		wait = false
		next_line()


func _on_Timer_timeout():
	wait = false
	next_line()
