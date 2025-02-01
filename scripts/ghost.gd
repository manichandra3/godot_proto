extends CharacterBody2D

class_name GhostCharacter

# Movement constants
const MOVE_SPEED: float = 40.0
const ACCELERATION: float = 500.0
const DECELERATION: float = 700.0
const ARRIVAL_THRESHOLD: float = 2.0

# Animation states
enum AnimationState {
	IDLE,
	WALK_UP,
	WALK_DOWN,
	WALK_LEFT,
	WALK_RIGHT
}

# Node references
@onready var sprite: AnimatedSprite2D = $ghost_animated
@onready var current_state: AnimationState = AnimationState.IDLE

# Movement variables
var target_pos: Vector2
var desired_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	target_pos = self.global_position
	play_animation(AnimationState.IDLE)

func _process(_delta: float) -> void:
	handle_input()

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	update_animation()

func handle_input() -> void:
	if Input.is_action_just_pressed("click"):
		set_new_target(get_global_mouse_position())

func set_new_target(new_pos: Vector2) -> void:
	target_pos = new_pos

func handle_movement(delta: float) -> void:
	var distance_to_target = self.global_position.distance_to(target_pos)
	
	if distance_to_target > ARRIVAL_THRESHOLD:
		# Calculate desired velocity
		var direction = (target_pos - self.global_position).normalized()
		desired_velocity = direction * MOVE_SPEED
		
		# Smoothly accelerate towards desired velocity
		velocity = velocity.move_toward(desired_velocity, ACCELERATION * delta)
		
		# Move and slide handles the collision response
		move_and_slide()
		
		# After collision, maintain speed but slide along walls
		if get_slide_collision_count() > 0:
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				if collision:
					# Project velocity along the wall
					velocity = velocity.slide(collision.get_normal())
					velocity = velocity.normalized() * MOVE_SPEED
	else:
		# Smoothly decelerate to a stop
		desired_velocity = Vector2.ZERO
		velocity = velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
		move_and_slide()
		
		if velocity.length() < 0.1:
			velocity = Vector2.ZERO

func update_animation() -> void:
	var new_state: AnimationState
	
	if velocity.length() < 0.1:
		new_state = AnimationState.IDLE
	else:
		# Determine animation based on movement direction
		if abs(velocity.x) > abs(velocity.y):
			new_state = AnimationState.WALK_RIGHT if velocity.x > 0 else AnimationState.WALK_LEFT
		else:
			new_state = AnimationState.WALK_DOWN if velocity.y > 0 else AnimationState.WALK_UP
	
	if new_state != current_state:
		play_animation(new_state)
		current_state = new_state

func play_animation(state: AnimationState) -> void:
	match state:
		AnimationState.IDLE:
			sprite.play("idle")
		AnimationState.WALK_UP:
			sprite.play("walk_w")
		AnimationState.WALK_DOWN:
			sprite.play("walk_s")
		AnimationState.WALK_LEFT:
			sprite.play("walk_a")
		AnimationState.WALK_RIGHT:
			sprite.play("walk_d")

func teleport(new_pos: Vector2) -> void:
	self.global_position = new_pos
	target_pos = new_pos
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO

func stop_movement() -> void:
	target_pos = self.global_position
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO

func is_moving() -> bool:
	return velocity.length() > 0.1
