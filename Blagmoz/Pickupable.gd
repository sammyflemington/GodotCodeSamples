extends KinematicBody2D
class_name Pickupable
# Defines online syncing behavior of physics objects that can be picked up by players

export var GRAVITY = 800
export var FRIC_FLOOR = 9.7
export var FRIC_AIR = 2.7
export var bounciness = 0.5
export var BREAK_VELOCITY = -1

export var poof_scn = preload("res://Scenes/LevelParts/Pickupables/SpeedPotionPoof.tscn")

var held = false
var velocity = Vector2.ZERO

onready var collision_shape = $CollisionShape2D
export var spin_on_bounce = true
var rotation_rate = 0

var puppet_position = Vector2.ZERO setget puppet_position_set
var puppet_velocity = Vector2.ZERO setget puppet_velocity_set
var pos_tween
export var throwable = true
export var THROW_STRENGTH = 70.0

export var stick_in_walls = false
var stuck_pos = Vector2.ZERO
var stuck_to = null
export (float) var wall_stick_angle = 0.0

export (bool) var low_throw_arc = false
var is_stuck_in_wall = false

var last_synced_pos = Vector2.ZERO

# Free sim is a temporary state where the physics of the object are not synced, which removes network
# latency and improves the feeling of responsiveness
var free_sim_timer
var free_sim = false
# This tween blends the sync back in as the free sync state is closed
var sync_blend_time = .5
var sync_blend_progress = 1.0
var sync_blend_tween : Tween

var last_holder = -1
var throw_sound
export var display_name = ""
signal picked_up()
signal thrown()

var home_z_index = 0
var timer_scn = preload("res://Scenes/LevelParts/Pickupables/FreeSimTimer.tscn")
var through_one_way_timer



var shader_material = preload("res://Scenes/LevelParts/Pickupables/PotionShader.tres")
export var outline_color = Color(1,1,1,1)
export var auto_set_material = true

func _ready():
	home_z_index = z_index
	throw_sound = AudioStreamPlayer2D.new()
	throw_sound.bus = "Players"
	throw_sound.volume_db = -3
	throw_sound.stream = load("res://Sounds/throw_sound.wav")
	throw_sound.set_script(load("res://Player/SoundEffectPlayer.gd"))
	add_child(throw_sound)
	pos_tween = Tween.new()
	add_child(pos_tween)
	
	free_sim_timer = timer_scn.instance()
	free_sim_timer.wait_time = 2
	free_sim_timer.connect("timeout", self, "_on_free_sim_timer_timeout")
	add_child(free_sim_timer)
	
	through_one_way_timer = timer_scn.instance()
	through_one_way_timer.wait_time = .2
	through_one_way_timer.connect("timeout", self, "_on_through_one_way_timer_timeout")
	add_child(through_one_way_timer)
	
	sync_blend_tween = Tween.new()
	add_child(sync_blend_tween)
	
	if !Globals.physics_active:
		set_physics_process(false)
	shader_material.set_shader_param("outline_color", Color(outline_color.r * 1.3, outline_color.g * 1.3, outline_color.b * 1.3, 1))
	
	if get_node("Sprite") != null:
		get_node("Sprite").use_parent_material = true

func update_physics_process():
	set_physics_process(Globals.physics_active)

# Allows objects to pass through one-way platforms for a short time after being thrown
func _on_through_one_way_timer_timeout():
	set_collision_layer_bit(1, true)

# Some objects jiggle and make noise when a player walks past them
func jiggle():
	pass

# Free sim ends and synced behavior is blended back in
func _on_free_sim_timer_timeout():
	free_sim = false
	velocity = puppet_velocity
	sync_blend_tween.stop_all()
	sync_blend_tween.remove_all()
	sync_blend_tween.interpolate_property(self, "sync_blend_progress", 0.0, 1.0, sync_blend_time)
	sync_blend_tween.start()

func pick_up(player_id):
	if !held:
		SteamNetwork.rpc_remote_sync(self, "give_to_player", true, [player_id])
	else:
		SteamNetwork.rpc_on_client(player_id, Players.get_player(player_id), "give_to_player_failed", true)
		

func puppet_position_set(new_val):
	puppet_position = new_val
	if !held and !free_sim:
		pos_tween.interpolate_property(self, "position", position, ((puppet_position - position) * sync_blend_progress) + position, Network.tick_time_pickups)
		pos_tween.start()

func puppet_velocity_set(new_val):
	puppet_velocity = new_val
	if !free_sim:
		velocity = puppet_velocity

# Syncing function
func s(pos, vel):
	puppet_position_set(pos)
	puppet_velocity_set(vel)

func network_update(counter):
	# Called on server only. Skip update if I haven't moved since last update
	if (position - last_synced_pos).length() > 3 and !held:
		last_synced_pos = position
		if SteamNetwork.is_server():
			SteamNetwork.rpc_all_clients(self, "s", false, [position, velocity])
		
func get_last_holder():
	return last_holder

func held_position_update(pos, aim):
	if held:
		global_position = pos
		scale = Vector2(aim, 1)
	
func give_to_player(player_id):
	var pos = global_position
	if get_parent() != Globals.currentLevel:
		get_parent().remove_child(self)
		Globals.currentLevel.add_child(self)
	global_position = pos
	var p = Players.get_player(player_id)
	
	held = true
	collision_shape.set_deferred("disabled", true)

	rotation = 0
	velocity = Vector2.ZERO
	puppet_velocity = Vector2.ZERO
	last_holder = player_id
	emit_signal("picked_up")
	is_stuck_in_wall = false
	stuck_to = null
	if p != null:
		p.add_held_item(self)

# A player can call this function to throw their held item
func throw(pos: Vector2, vel:Vector2, hard_throw : bool):
	if throwable:
		emit_signal("thrown")
		set_deferred("global_position", pos)
		var player = Players.get_player(last_holder)
		# Disconnect animation signals
		if player != null:
			if player.is_connected("hand_position_update", self, "held_position_update"):
				player.disconnect("hand_position_update", self, "held_position_update")
			if player.is_connected("shown", self, "show"):
				player.disconnect("shown", self, "show")
		
		throw_sound.play_rand()
		
		if vel.y == 0:
			if low_throw_arc:
				velocity = Vector2(vel.x, -.2).normalized() * THROW_STRENGTH
			else:
				velocity = Vector2(vel.x, -.5).normalized() * THROW_STRENGTH
		else:
			velocity = Vector2(vel.x / 2.5, vel.y).normalized() * THROW_STRENGTH
		if hard_throw:
			velocity *= 5
		else:
			velocity /= 2
		held = false
		if !SteamNetwork.is_server():
			#puppet_velocity_set(velocity)
			sync_blend_progress = 0.0
			free_sim = true
			free_sim_timer.start()
		if spin_on_bounce:
			rotation_rate = rand_range(-3, 3)
		collision_shape.set_deferred("disabled", false)
		if !hard_throw:
			set_collision_layer_bit(1, false)
		through_one_way_timer.start()

func _physics_process(dt):
	if held:
		rotation = 0
		z_index = 16 # Always show a held object on top of the player character
	else:
		z_index = home_z_index
	
	if is_stuck_in_wall:
		velocity = Vector2.ZERO
		if stuck_to == null:
			global_position = stuck_pos
			
	# If no sync packets have been recieved recently OR this pickup is in the free_sim state OR this is the server, simulate its physics and check for collisions.
	if (!pos_tween.is_active() or free_sim or sync_blend_tween.is_active()) and !is_stuck_in_wall:
		if !held and !is_stuck_in_wall:
			
			# Move and check for collisions
			var collision_info = move_and_collide(velocity * dt)
			if collision_info:
				if stick_in_walls and (collision_info.collider.is_in_group("terrain") or collision_info.collider.is_in_group("oneWays")):
					
					# Sticking in walls -- Server only --
					if SteamNetwork.is_server():
						var collider = collision_info.collider
						if collider is KinematicBody2D:
							# Stick and move with this object (a moving platform probably)
							var colliderPath = get_tree().get_root().get_path_to(collider)
							SteamNetwork.rpc_remote_sync(self, "stick_in_wall", true, [global_position, collision_info.normal, colliderPath])
						else:
							SteamNetwork.rpc_remote_sync(self, "stick_in_wall", true, [global_position, collision_info.normal])
						return
					
				velocity = velocity.bounce(collision_info.normal)
				
				bounce_fx(velocity, collision_info.normal)
				
				# If a collision is fast enough, this pickup will break.
				if SteamNetwork.is_server():
					if BREAK_VELOCITY != -1: # -1 indicates an unbreakable pickup
						if (velocity.dot(collision_info.normal)) > BREAK_VELOCITY:
							SteamNetwork.rpc_remote_sync(self, "shatter", true, [global_position, Globals.next_projectile()])
				else:
					# Upon a collision, free_sim state is always exited.
					if free_sim:
						_on_free_sim_timer_timeout()
				velocity *= bounciness
				var discard = move_and_slide(collision_info.collider_velocity)
			
			velocity.y += GRAVITY*dt
			velocity.x -= velocity.x * FRIC_AIR * dt

# Tell this object to stick in a wall. Used on the Tomahawk weapon.
func stick_in_wall(pos: Vector2, collision_normal : Vector2, collider_path: NodePath = NodePath("")):
	is_stuck_in_wall = true
	stuck_pos = pos
	free_sim = false
	free_sim_timer.stop()
	if collider_path != NodePath(""):
		# this will be a kinematic body
		stuck_to = get_tree().get_root().get_node_or_null(collider_path)
		if stuck_to != null:
			get_parent().call_deferred("remove_child", self)
			stuck_to.call_deferred("add_child", self)
	set_deferred("global_position", pos)
	puppet_velocity_set(Vector2.ZERO)

func bounce_fx(vel, normal):
	rotation_rate = 0

func shatter(pos, id):
	pass

# Used to clear unused pickupables after a level is over
func destroy():
	if !held: # pickups being held by a player are brought into the next level
		queue_free()
	else:
		var p = global_position
		get_parent().remove_child(self)
		Globals.currentLevel.call_deferred("add_child", self)
		global_position = p

func knock_back(vel : Vector2):
	velocity += vel

# Used to highlight an object that a player will pick up
var highlighted = false
func set_highlighted(mat):
	if !highlighted:
		highlighted = true
		material = mat

func disable_highlighted():
	if highlighted:
		highlighted = false
		material = null
