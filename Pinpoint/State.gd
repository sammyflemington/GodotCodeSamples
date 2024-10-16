extends Node
class_name State

var parent : CharacterBody2D
var state_machine : StateMachine

func init(p: CharacterBody2D):
	parent = p

func on_enter():
	return

func on_exit():
	return

func process_physics(_dt):
	pass

func process_input(_dt, _input: Vector2):
	pass

func process_jump(_jump: bool):
	pass
