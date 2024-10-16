extends CharacterBody2D
class_name Player

@export var velocity_component: VelocityComponent
@export var health_component: HealthComponent
@export var hook_component : HookComponent
@export var weapon_component : WeaponComponent
@export var juice_component : JuiceManagerComponent
@export var state_machine : StateMachine
@onready var item_manager : ItemManagerComponent = $ItemManagerComponent
@onready var beam_anim = $BeamEffects/AnimationPlayer

@onready var sprite = $AnimatedSprite2D
var dead = false

func _ready():
	Globals.player = self
	health_component.health_changed.connect(Hud.dying_overlay.player_health_changed)
	health_component.health_changed.connect(Hud.health_bar.player_health_changed)
	health_component.init()

func _physics_process(dt):
	var input = Input.get_vector("left", "right", "up", "down")
	
	state_machine.process_input(dt, input)
	state_machine.process_jump(Input.is_action_just_pressed("jump"))
	state_machine.process_physics(dt)
	
	velocity = velocity_component.get_velocity()
	
	var mouse_pos_relative  := Globals.get_mouse_world_pos() - global_position
	

	move_and_slide()
	velocity_component.set_velocity(velocity)
	if dead:
		return
	
	# Aiming
	var aim : Vector2
	if Globals.input_device == -1:
		aim = mouse_pos_relative.normalized()
	else: 
		aim = Globals.get_right_stick()
	
	if abs(aim.x) > 0:
		sprite.scale.x = sign(aim.x)
	
	weapon_component.set_aim(aim)
	hook_component.set_ray_direction(aim)
	
	hook_component.set_connect(Input.is_action_pressed("mb_right"))
	
	if Input.is_action_pressed("shoot"):
		weapon_component.start_fire()
	else:
		weapon_component.release_fire()
	
	if Input.is_action_just_pressed("ability"):
		item_manager.use_ability(aim)

func gain_juice(_amount):
	juice_component.add_juice(.01)

func _on_health_component_health_depleted():
	dead = true
	weapon_component.disable()
	hook_component.set_connect(false)

func teleport(pos: Vector2):
	position = pos
	velocity_component.set_velocity(Vector2.ZERO)

func oob_teleport(pos: Vector2):
	teleport(pos)
	health_component.take_damage_percentage(0.3)
	beam_anim.play("TeleportSmall")

func _on_health_component_damage_taken(dmg, shield_damage_only : bool):
	if dmg > 30:
		# big impact
		SlowMotionManager.slow_mo_impact_big_damage_taken()
		if Globals.camera:
			Globals.camera.abberate(5)
			Globals.camera.shake(10)
	else:
		SlowMotionManager.slow_mo_impact_small()
		if Globals.camera:
			Globals.camera.abberate(0.5)
			Globals.camera.shake(3)
			
