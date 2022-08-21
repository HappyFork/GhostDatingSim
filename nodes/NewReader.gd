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
# # "text" - ("name"), ("speaking"), "text"
# # "choice" - ("name"), ("speaking"), "text", "choices"
# # "room" - "target", "action"
# # "stage" - "slot", "portrait", "anim"
# # "variable" - "variable", "value"
# # "inventory" - "variable", "action"
# # "change_room" - "room"
# # "sound" - (TODO: work in progress)
# # "wait" - "time"
#
# Every line (except "choice" and "change_room") will also have a "next" key,
# indicating which index the reader will parse next. If "next": "end", the
# cutscene ends. "change_room" lines will always end a scene, so no "next" is necessary.
# 
# The "choices" key in "choice" is a dictionary of single-numeral keys, the values
# of which are dictionaries containing "text" and "next keys. The "next" is
# therefore determined by which choice the player chooses.
#
# So, to get to a choice, you need dictionary[index]["choices"]["1"]["text"]
# The penultimate [] = which choice key, the last [] = text or next. (This is so
# complicated just so I can have a variable number of choices).



### --- Variables --- ###

# Onready variables (in rough order of scene tree placement)
onready var sprite_slots = [ $Sprite1, $Sprite2, $Sprite3, $Sprite4 ] # The sprite slots
onready var nl_box = $Nameless # The main dialogue box without an accompanying name box
onready var nl_text = $Nameless/TextLabel # The text container in the nameless dialogue box
onready var n_box = $Name # The main dialogue box with accompanying name box
onready var n_text = $Name/TextLabel # The main text container in the dialogue box w/ name
onready var n_name = $Name/NameLabel # The name text container
onready var tween = $Tween # The tween that moves the sprites
onready var wait_timer = $Timer # Timer used to wait
onready var choice_anim = $AnimationPlayer # The animation player that flips the choices


# Regular variables
var filepath = "" # The .json filepath to the reader file.
var dictionary : Dictionary # Holds the loaded in reader file.
var index # The index of the reader dictionary that is currently displayed

var active_choice = 0 # The choice option currently selected. Should be 0 if the current index isn't type choice
var choices = [] # Holds the choice dictionaries while a choice is active
var active_sprite = 0 # Which of the sprites is not greyed out. Should be 0 if there are no sprites loaded
var wait = false # If the reader is currently waiting
var grey = Color(0.5,0.5,0.5,1) # Darker than the built-in darkgrey


# Signals
signal read_started # Emitted at the start of a cutscene, prevents player from taking inputs
signal read_ended # Emitted when the reader closes, returning control to the player

# Signals that "room" lines emit
signal player_turned( dir )
signal player_stepped
signal porch_camera_snapped
signal foyer_willow_entered
signal foyer_willow_snapped



### --- Engine functions --- ###

# Opens a test file. Used for testing. Comment out when not in use.
#func _ready():
#	start( "res://readerfiles/test.json", "001" )


# Runs when there is an input event
func _input(event):
	# Only does anything when there's a dictionary loaded in
	if( dictionary.size() > 0 ):
		# If the current index is type text
		if dictionary[index]["type"] == "text":
			# If the input event is interact
			if( event.is_action_pressed("interact") ):
				# Advance to the next line
				next_line()
		
		# If the current index is type choice
		elif dictionary[index]["type"] == "choice":
			# If the input event is interact
			if( event.is_action_pressed("interact") and !choice_anim.is_playing() ):
				var nexind = dictionary[index]["choices"][str(active_choice)]["next"]
				clear_choice()
				next_line( nexind )
			# Else, if the input event is up
			elif( event.is_action_pressed("move_up") ):
				if choice_anim.is_playing():
					choice_anim.stop()
					reset_choice_boxes()
				else:
					# Flip the choices backward
					match choices.size():
						2:
							choice_anim.play("Flip2Backward")
						3:
							choice_anim.play("Flip3Backward")
						4:
							choice_anim.play("Flip4Backward")
						_:
							choice_anim.play("Flip5Backward")
					# And set the previous choice as active
					if active_choice == 1:
						active_choice = choices.size()
					else:
						active_choice -= 1
			# Else, if the input is down
			elif( event.is_action_pressed("move_down") ):
				if choice_anim.is_playing():
					choice_anim.stop()
					reset_choice_boxes()
				else:
					# Flip the choices forward
					match choices.size():
						2:
							choice_anim.play("Flip2Forward")
						3:
							choice_anim.play("Flip3Forward")
						4:
							choice_anim.play("Flip4Forward")
						_:
							choice_anim.play("Flip5Forward")
					# And set the next choice as active
					if active_choice == choices.size():
						active_choice = 1
					else:
						active_choice += 1



### --- Custom functions --- ###

# Starts the reader event using the passed in script on the passed in index
func start(fp, start):
	emit_signal("read_started")
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
# it its own function.
func next_line( next = "" ):
	# Only does anything when there's a dictionary loaded in
	if( dictionary.size() > 0 ):
		if next == "":
			index = dictionary[index]["next"]
		else:
			index = next
		parse_index()


# Displays things based on the information at the current index in the loaded dictionary
func parse_index():
	# If index is end, end the reader and don't execute the rest of the function
	if index == "end":
		end()
		return
	
	# Parses each line differently depending on what type it is. See the top of
	# this document to see the different types and what they do. 
	match dictionary[index]["type"]:
		"text": # Changes the text displayed in the main text box
			if dictionary[index].has( "name" ):
				nl_box.hide()
				n_name.text = dictionary[index]["name"]
				n_text.text = dictionary[index]["text"]
				for x in sprite_slots.size():
					if x == dictionary[index]["speaking"] - 1:
						sprite_slots[x].modulate = Color.white
					else:
						sprite_slots[x].modulate = grey
				if( !n_box.visible ):
					n_box.show()
			else:
				n_box.hide()
				nl_text.text = dictionary[index]["text"]
				for x in sprite_slots.size():
					sprite_slots[x].modulate = grey
				if( !nl_box.visible ):
					nl_box.show()
			
		"choice": # Allows player to choose between two options
			# This section is literally copy-pasted from "text"...
			if dictionary[index].has( "name" ):
				nl_box.hide()
				n_name.text = dictionary[index]["name"]
				n_text.text = dictionary[index]["text"]
				for x in sprite_slots.size():
					if x == dictionary[index]["speaking"] - 1:
						sprite_slots[x].modulate = Color.white
					else:
						sprite_slots[x].modulate = grey
				if( !n_box.visible ):
					n_box.show()
			else:
				n_box.hide()
				nl_text.text = dictionary[index]["text"]
				for x in sprite_slots.size():
					sprite_slots[x].modulate = grey
				if( !nl_box.visible ):
					nl_box.show()
			
			# Add the choice dictionaries (containing "text" and "next" keys) into an array
			for c in dictionary[index]["choices"]:
				choices.append(dictionary[index]["choices"][c])
			
			# Set the active choice to 1
			active_choice = 1
			
			# Show the correct number of boxes based on how many choices there are.
			# (There might be an easier way to do this using $ChoiceBoxes.get_children but...
			# that's too complicated for me right now. Maybe I'll figure it out later)
			match choices.size():
				2:
					$ChoiceBoxes/ChoiceBox1/Label.text = choices[0]["text"]
					$ChoiceBoxes/ChoiceBox2/Label.text = choices[1]["text"]
					
					$ChoiceBoxes/ChoiceBox1.show()
					$ChoiceBoxes/ChoiceBox2.show()
				3:
					$ChoiceBoxes/ChoiceBox1/Label.text = choices[0]["text"]
					$ChoiceBoxes/ChoiceBox2/Label.text = choices[1]["text"]
					$ChoiceBoxes/ChoiceBox3/Label.text = choices[2]["text"]
					
					$ChoiceBoxes/ChoiceBox1.show()
					$ChoiceBoxes/ChoiceBox2.show()
					$ChoiceBoxes/ChoiceBox3.show()
				4:
					$ChoiceBoxes/ChoiceBox1/Label.text = choices[0]["text"]
					$ChoiceBoxes/ChoiceBox2/Label.text = choices[1]["text"]
					$ChoiceBoxes/ChoiceBox3/Label.text = choices[2]["text"]
					$ChoiceBoxes/ChoiceBox5/Label.text = choices[3]["text"]
					
					$ChoiceBoxes/ChoiceBox1.show()
					$ChoiceBoxes/ChoiceBox2.show()
					$ChoiceBoxes/ChoiceBox3.show()
					$ChoiceBoxes/ChoiceBox5.show()
				_:
					$ChoiceBoxes/ChoiceBox1/Label.text = choices[0]["text"]
					$ChoiceBoxes/ChoiceBox2/Label.text = choices[1]["text"]
					$ChoiceBoxes/ChoiceBox3/Label.text = choices[2]["text"]
					$ChoiceBoxes/ChoiceBox5/Label.text = choices[-1]["text"]
					
					for cb in $ChoiceBoxes.get_children():
						cb.show()
			
		"room": # Sends a signal to the current room to do something
			# Not a fan of nested match statements. There has to be a better way to do this
			match dictionary[index]["target"]:
				"player":
					match dictionary[index]["action"]:
						"turn":
							emit_signal("player_turned", dictionary[index]["direction"])
							next_line()
						"step":
							emit_signal("player_stepped")
							wait = true
					
				"camera":
					if dictionary[index]["action"] == "snap":
						emit_signal("porch_camera_snapped")
						next_line()
				"foyer":
					if dictionary[index]["action"] == "willow_enter":
						emit_signal("foyer_willow_entered")
						wait = true
					elif dictionary[index]["action"] == "willow_snap":
						emit_signal("foyer_willow_snapped")
						next_line()
		
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


# Resets the choice boxes to their original position, and populates the labels according to the active choice
func reset_choice_boxes():
	var next = active_choice
	var twext = active_choice + 1
	var prev = active_choice - 2
	
	if next == choices.size():
		next = 0
		twext = 1
	elif twext == choices.size():
		twext = 0
	
	choice_anim.seek(0, true) # choice_anim.play("RESET") caused the lables to flicker, but this works!
	# Shout outs to newjoker6#4179 on discord!
	
	match choices.size(): # This is the third time I've used this same match statement
		# I need to find another way to do this
		2:
			$ChoiceBoxes/ChoiceBox1/Label.text = choices[active_choice - 1]["text"]
			$ChoiceBoxes/ChoiceBox2/Label.text = choices[next]["text"]
		_:
			$ChoiceBoxes/ChoiceBox1/Label.text = choices[active_choice - 1]["text"]
			$ChoiceBoxes/ChoiceBox2/Label.text = choices[next]["text"]
			$ChoiceBoxes/ChoiceBox3/Label.text = choices[twext]["text"]
			$ChoiceBoxes/ChoiceBox5/Label.text = choices[prev]["text"]


# Clears the reader elements that are only used for choices
func clear_choice():
	#choice1_arrow.hide()
	#choice1_text.text = ""
	#choice2_arrow.hide()
	#choice2_text.text = ""
	for cb in $ChoiceBoxes.get_children():
		cb.hide()
	$ChoiceBoxes/ChoiceBox1/Label.text = ""
	$ChoiceBoxes/ChoiceBox2/Label.text = ""
	$ChoiceBoxes/ChoiceBox3/Label.text = ""
	$ChoiceBoxes/ChoiceBox4/Label.text = ""
	$ChoiceBoxes/ChoiceBox5/Label.text = ""
	active_choice = 0
	choices = []


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
	# TODO: just double check that this function works correctly once all the changes
	# are made. It should hide both main boxes and reset the choices properly.
	
	# Empties the dictionary
	dictionary = {}
	
	# Resets the reader file
	filepath = ""
	
	# Hides the reader box and choice arrows
	n_box.hide()
	nl_box.hide()
	#choice1_arrow.hide()
	#choice2_arrow.hide()
	
	# Empties the text fields
	n_text.text = ""
	n_name.text = ""
	nl_text.text = ""
	
	# Reset the choice stuff
	clear_choice()
	
	# Reset the sprites
	reset_all_sprites()
	
	# Resets wait if it's set to true
	wait = false
	
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


func _on_AnimationPlayer_animation_finished(anim_name):
	# Only does anything if there's an active choice index
	if dictionary[index]["type"] == "choice":
		reset_choice_boxes()
