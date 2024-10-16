extends Node
class_name StateMachine

@export var parent : CharacterBody2D
@export var current_state : State
@export var dead_state : State

func _ready():
	init()
	if current_state == null:
		if len(get_children()) > 0:
			current_state = get_children()[0]
		else:
			assert(false, "State machine %s has no states!"%self)

func init():
	for state in get_children():
		state.parent = parent
		state.state_machine = self
	current_state.on_enter()

func change_state(state_to: State):
	if state_to == current_state:
		return
	current_state.on_exit()
	current_state = state_to
	current_state.on_enter()

func process_physics(dt):
	current_state.process_physics(dt)

func process_input(dt, input: Vector2):
	current_state.process_input(dt, input)

func process_jump(jump: bool):
	current_state.process_jump(jump)

func _on_health_depleted():
	change_state(dead_state)
