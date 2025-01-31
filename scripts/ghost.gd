class_name ghost_animated
extends CharacterBody2D

@export var speed: float = 300.0
var agent: NavigationAgent2D  # Remove @export if assigning dynamically

func _ready():
	agent = $NavigationAgent2D  # Automatically find the NavigationAgent2D node

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			agent.target_position = get_global_mouse_position()

func _physics_process(delta):
	if not agent:  # Check if agent is valid
		return
	
	var target_pos = agent.get_next_path_position()
	var direction = (target_pos - global_position).normalized()

	if agent.is_navigation_finished() or target_pos.distance_to(global_position) < 3:
		velocity = Vector2.ZERO
	else:
		velocity = direction * speed

	move_and_slide()
