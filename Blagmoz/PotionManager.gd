extends Node
# Autoloaded scene that manages potions.
# Chooses potions to be spawned in various scenarios, synchronizes application of potion effect scripts,
# and applies the potion loadouts configured in the Potion Picker screen.
var potions = {
	0: preload("res://Data/BlindingPotion.tres"),
	1: preload("res://Data/CleansingPotion.tres"),
	2: preload("res://Data/CullingPotion.tres"),
	3: preload("res://Data/DeathPotion.tres"),
	4: preload("res://Data/FeatherFootPotion.tres"),
	5: preload("res://Data/HexPotion.tres"),
	6: preload("res://Data/MushroomPotion.tres"),
	7: preload("res://Data/OozeFasterPotion.tres"),
	8: preload("res://Data/OozeSlowerPotion.tres"),
	9: preload("res://Data/SpeedPotion.tres"),
	10: preload("res://Data/StudiousPotion.tres"),
	11: preload("res://Data/TeleportBook.tres"),
	12: preload("res://Data/TeslaPotion.tres"),
	13: preload("res://Data/WallGrabPotion.tres"),
	14: preload("res://Data/BubbleShieldPotion.tres"),
	15: preload("res://Data/LowGravityPotion.tres"),
	16: preload("res://Data/GreekFirePotion.tres"),
	17: preload("res://Data/SkeletonCorpse.tres"),
	18: preload("res://Data/InvisibilityPotion.tres"),
	19: preload("res://Data/WingsPotion.tres"),
	20: preload("res://Data/LightningPotion.tres"),
	21: preload("res://Data/AlchemistPotion.tres"),
	22: preload("res://Data/InfinityPotion.tres"),
	23: preload("res://Data/MidasPotion.tres")
}

var gnome_potions_list = [9, 13, 14, 19, 5, 3, 15] # pool for potions from the Gnome statue
var editor_potions_list = [0,1,2,3,4,5,7,8,9,10,11,12,13,14,15,16,18,19,20,23] # potions available in level editor

# Stores data about the player-configured starting potions that are applied every level.
var potion_loadouts = {}
var has_potion_loadouts = false

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(len(potions)):
		potions[i].potion_id = i

func register_my_rpcs():
	SteamNetwork.register_rpc_quick(self, "apply_potion_effect")
	SteamNetwork.register_rpc_quick(self, "apply_drink_potion_effect")
	SteamNetwork.register_rpc_quick(self, "set_has_potion_loadouts")
	SteamNetwork.register_rpc_quick(self, "request_has_potion_loadouts")

func apply_potion_effect(player_num_target, player_num_applicator, potion_id):
	Players.get_player(player_num_target).add_potion(potions[potion_id].instance_effect(), player_num_applicator)
	if Players.get_player(player_num_target).is_master():
		HintOverlay.show_potion_hint(potions[potion_id])

func apply_drink_potion_effect(player_num_target, player_num_applicator, potion_id, show_banner = true, start_paused = false):
	Players.get_player(player_num_target).add_potion(potions[potion_id].instance_drink_effect(), player_num_applicator, show_banner)
	if start_paused:
		Players.get_player(player_num_target).pause_potion_timers()

func get_next_floor_potion():
	var options = []
	for potion in potions.keys():
		if potions[potion].floor_pool and potions[potion].is_unlocked() and potions[potion].is_available() :
			options.append(potion)
	return options[randi()%len(options)]

func get_next_brown_chest_potion():
	var options = []
	for potion in potions.keys():
		if potions[potion].brown_chest_pool and potions[potion].is_unlocked() and potions[potion].is_available() :
			options.append(potion)
	return options[randi()%len(options)]

var last_gold_potion = -1
func get_next_gold_chest_potion():
	var options = []
	for potion in potions.keys():
		if potions[potion].gold_chest_pool and potions[potion].is_unlocked() and potions[potion].is_available() and potion != last_gold_potion:
			options.append(potion)
	last_gold_potion = options[randi()%len(options)]
	return last_gold_potion

func get_next_red_chest_potion():
	var options = []
	for potion in potions.keys():
		if potions[potion].red_chest_pool and potions[potion].is_unlocked() and potions[potion].is_available() :
			options.append(potion)
	return options[randi()%len(options)]


func get_next_rare_potion():
	var options = []
	for potion in potions.keys():
		if potions[potion].rare_pool and potions[potion].is_unlocked() and potions[potion].is_available() :
			options.append(potion)
	return options[randi()%len(options)]

func get_potion_value(potion_id):
	return potions[potion_id].value + 1

func get_potion(potion_id):
	return potions[potion_id]
func get_random_gnome_potion(playerId):
	var potion_id = 0
	var rand_int = randi()
	var available_potions = gnome_potions_list.duplicate()
	
	return available_potions[rand_int % len(available_potions)]
	
func get_editor_potions():
	var temp = {}
	for pid in editor_potions_list:
		temp[pid] = potions[pid]
	return temp

func set_potion_loadouts(dict:Dictionary):
	if not SteamNetwork.is_server():
		return
	potion_loadouts = dict
	
	for key in potion_loadouts.keys():
		if len(potion_loadouts[key].keys()) > 0:
			has_potion_loadouts = true
			return
	has_potion_loadouts = false
	

func set_has_potion_loadouts(tf:bool): # used to sync client configuration with the server
	has_potion_loadouts = tf

func request_has_potion_loadouts(requestor_id:int):
	if SteamNetwork.is_server():
		SteamNetwork.rpc_on_client(requestor_id, self, "set_has_potion_loadouts", true, [has_potion_loadouts])

func get_potion_loadouts()->Dictionary:
	return potion_loadouts

func has_potion_loadouts() -> bool:
	return has_potion_loadouts

var players_who_died = []
func _on_player_died(player_id):
	print(player_id, "died!")
	if SteamNetwork.is_server():
		players_who_died.append(player_id)

func _on_next_level():
	yield(get_tree().create_timer(0.1), "timeout")
	print("Next level potion picker!")
	print("Players who died: ", players_who_died)
	apply_potion_loadouts()
	players_who_died = []

func _on_start_game():
	players_who_died = Players.get_all_player_ids()
	SteamNetwork.rpc_remote_only(self, "set_has_potion_loadouts", true, [has_potion_loadouts])

func apply_potion_loadouts():
	if SteamNetwork.is_server():
		for player_id in Players.get_all_player_ids():
			if potion_loadouts.has(player_id):
				var died = player_id in players_who_died
				for potion_id in potion_loadouts[player_id]:
					if died:
						for i in range(potion_loadouts[player_id][potion_id]):
							print("Applying potion to %s" % player_id)
							SteamNetwork.rpc_remote_sync(self, "apply_drink_potion_effect", true, [player_id, -1, potion_id, false, true])
					else:
						if !Players.get_player(player_id).has_potion_id(potion_id):
							for i in range(potion_loadouts[player_id][potion_id]):
								print("Applying potion to %s" % player_id)
								SteamNetwork.rpc_remote_sync(self, "apply_drink_potion_effect", true, [player_id, -1, potion_id, false, true])
						else:
								SteamNetwork.rpc_remote_sync(Players.get_player(player_id), "restart_potion_timer", true, [potion_id])
