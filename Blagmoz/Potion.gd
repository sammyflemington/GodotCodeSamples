extends Pickupable
class_name Potion

var potion_id = 0
# Color of the potion explosion when broken
export (Color) var poof_color = Color(1,1,1,1)
var bounce_sound_player
signal drank()
export (bool) var drinkable = true
var light_scn = preload("res://Scenes/LevelParts/Pickupables/PotionLight.tscn")
export var bounce_sound = preload("res://Sounds/bottle_land.wav")
# Does this potion have a unqiue effect when drank vs spilled?
var has_unique_drink_effect = false

onready var sprite = $Sprite

func _ready():
	set_collision_layer_bit(12, true)
	
	z_index = 22
	home_z_index = z_index
	z_as_relative = false
	
	bounce_sound_player = AudioStreamPlayer2D.new()
	bounce_sound_player.set_script(load("res://Player/SoundEffectPlayer.gd"))
	bounce_sound_player.stream = bounce_sound
	add_child(bounce_sound_player)
	bounce_sound_player.rand_offset_range = .15
	bounce_sound_player.bus = "Players"
	bounce_sound_player.volume_db = -10
	
	# Make potions light up and glow
	var light = light_scn.instance()
	light.set_color(poof_color)
	add_child(light)
	modulate = Color(1.4,1.4,1.4,1.0)
	
	# Non-throwable potions are used in the tutorial only and cannot be broken to avoid softlock
	if !throwable:
		BREAK_VELOCITY = -1


func jiggle():
	.jiggle()
	bounce_sound_player.play_rand()
	sprite.rotation = rand_range(-.5, .5)
	if velocity.length() < 5:
		velocity += Vector2(0, -40)

func _process(dt):
	if velocity.length() > 10:
		sprite.rotation += rotRate * dt * 8
		rotRate -= rotRate * dt 
	
func drink(player_id):
	if drinkable:
		emit_signal("drank")
		
		# PotionManager handles online syncing of potion effects
		if has_unique_drink_effect:
			PotionManager.apply_drink_potion_effect(player_id, player_id, potion_id)
		else:
			PotionManager.apply_potion_effect(player_id, player_id, potion_id)
		queue_free()

var broken = false
func shatter(pos, id):
	.shatter(pos, id)
	if !broken:
		var e = poofScn.instance()
		e.name = "poof"+str(id)
		e.potion_id = potion_id
		e.player_id = last_holder
		e.modulate = poof_color
		Globals.current_level.add_child(e)
		e.global_position = pos
		broken = true
		queue_free()

func give_to_player(player_id):
	.give_to_player(player_id)
	get_node("Sprite").rotation = 0

func use_in_craft():
	queue_free()

func bounce_fx(vel, normal):
	.bounce_fx(vel, normal)
	if vel.dot(normal) > 60 and vel.length() < BREAK_VELOCITY:
		bounce_sound_player.play_rand()
		sprite.rotation = rand_range(-.5, .5)

# Shatter potion if hitting an enemy player
func _on_PlayerHitter_body_entered(body):
	if body.is_in_group("player") and body.is_master() and body.playerNum != lastHolder:
		if BREAK_VELOCITY > 0 and velocity.length() > BREAK_VELOCITY:
			SteamNetwork.rpc_remote_sync(self, "shatter", true, [global_position, Globals.next_projectile()])
			print("Breaking with velocity ", velocity)
