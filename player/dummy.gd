extends CharacterBody3D
class_name Dummy

@export var speed = 8.0
@export var acceleration = 20.0
@export var jump_speed = 12.0
@export var mouse_sensitivity = 0.0015
@export var rotation_speed = 12.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var attacks = [
	"1h_slice_diagonal",
	"1h_slice_horizontal",
	"1h_attack_chop"
]
var is_attacking = false  # Add this new variable
var last_movement_direction = Vector3.FORWARD  # Defaults to facing forward
var stored_velocity = Vector3.ZERO  # Add this new variable

@onready var spring_arm = $SpringArm3D
@onready var model = $Rig
@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y += -gravity * delta
	
	# Handle movement
	if not is_attacking:
		get_move_input(delta)
	else:
		# Zero horizontal velocity during attack
		var vy = velocity.y
		velocity = Vector3.ZERO
		velocity.y = vy
	
	# Apply movement
	move_and_slide()
	
	# Handle model rotation based on movement direction
	if (velocity.length() > 1.0 or jumping) and not is_attacking:
		var target_rotation = atan2(-last_movement_direction.x, -last_movement_direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, rotation_speed * delta)
	
	# Handle jumping
	if is_on_floor() and Input.is_action_just_pressed("jump") and not is_attacking:  # Add not is_attacking check
		velocity.y = jump_speed
		jumping = true
		anim_tree.set("parameters/conditions/grounded", false)
		anim_tree.set("parameters/conditions/jumping", true)
		anim_state.travel("Jump_Start")
		await get_tree().create_timer(0.2).timeout
		if not is_on_floor():
			anim_state.travel("Jump_Idle")
	
	# Update animation states
	if not is_on_floor():
		anim_tree.set("parameters/conditions/jumping", true)
		anim_tree.set("parameters/conditions/grounded", false)  # Add this line
	
	# Landing detection
	if is_on_floor() and not last_floor:
		jumping = false
		anim_tree.set("parameters/conditions/jumping", false)
		anim_tree.set("parameters/conditions/grounded", true)
		# Check if there's any horizontal movement when landing
		if velocity.length() < 1.0:
			anim_tree.set("parameters/conditions/running", false)
		velocity.y = 0
		anim_state.travel("Jump_Land")

	last_floor = is_on_floor()
	
	# Falling detection
	if not is_on_floor() and not jumping and last_floor:  # Added last_floor check
		anim_state.travel("Jump_Idle")  # Changed from "Jump_Land" to "Jump_Idle"
		anim_tree.set("parameters/conditions/grounded", false)

func get_move_input(delta: float) -> void:
	var input = Input.get_vector("left", "right", "forward", "back")
	var direction = Vector3(input.x, 0, input.y)
	
	# Transform direction relative to camera orientation
	direction = direction.rotated(Vector3.UP, spring_arm.rotation.y)
	
	# Keep vertical velocity
	var vy = velocity.y
	velocity.y = 0
	
	# Apply movement
	if direction.length() > 0:
		last_movement_direction = direction
		velocity = lerp(velocity, direction.normalized() * speed, acceleration * delta)
		# Only change animation if we're on the ground and not in landing animation
		if is_on_floor() and anim_state.get_current_node() != "Jump_Land":
			anim_tree.set("parameters/conditions/running", true)
			anim_state.travel("Running")
	else:
		velocity = lerp(velocity, Vector3.ZERO, acceleration * delta)
		# Only change animation if we're on the ground and not in landing animation
		if is_on_floor() and anim_state.get_current_node() != "Jump_Land":
			anim_tree.set("parameters/conditions/running", false)
			anim_state.travel("Idle")
	
	# Restore vertical velocity
	velocity.y = vy

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -90.0, 30.0)
		spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
	
	if event.is_action_pressed("attack"):
		if not is_attacking and not jumping and is_on_floor():
			is_attacking = true
			stored_velocity = velocity  # Store current velocity
			velocity = Vector3.ZERO  # Zero out velocity to stop movement
			anim_state.travel(attacks.pick_random())
			
			# Reset running condition immediately
			anim_tree.set("parameters/conditions/running", false)
			
			# After attack animation, check input to set the correct state
			await anim_tree.animation_finished
			is_attacking = false
			
			var input = Input.get_vector("left", "right", "forward", "back")
			if input.length() > 0:
				velocity = stored_velocity  # Restore velocity if there's input
				anim_tree.set("parameters/conditions/running", true)
				anim_state.travel("Running")
			else:
				anim_state.travel("Idle")
