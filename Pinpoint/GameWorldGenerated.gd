extends Node2D

@export var block_count = 5
@export var normal_blocks : Array[PackedScene]
@export var lantern_blocks : Array[PackedScene]

@onready var level_block_holder = $Blocks
@onready var navigation_region = $NavigationRegion2D

var nav_border_size = 64
var block_height = 1024

signal world_gen_done()

func _ready():
	Globals.game_world = self


func generate_level(run_seed : int):
	seed(run_seed)
	
	# Choose 3 lantern blocks and fill the rest with normal blocks
	var blocks = []
	var lantern_block_pool = lantern_blocks.duplicate()
	for i in range(3):
		var block = lantern_block_pool[randi() % len(lantern_block_pool)]
		blocks.append(block.instantiate())
		lantern_block_pool.erase(block)
	
	var normal_block_pool = normal_blocks.duplicate()
	while len(blocks) < block_count:
		var block = normal_block_pool[randi() % len(normal_block_pool)]
		blocks.append(block.instantiate())
		normal_block_pool.erase(block)
	
	# Randomize order of level blocks
	blocks.shuffle()
	
	# Place blocks
	var offset_x = 0
	for block in blocks:
		level_block_holder.add_child(block)
		block.position.x = offset_x
		offset_x += block.block_size.x
	
	# Define and bake navigation mesh
	var bounding_outline = PackedVector2Array([Vector2(-nav_border_size, -nav_border_size), 
		Vector2(-nav_border_size, block_height + nav_border_size),
		Vector2(offset_x + nav_border_size, block_height + nav_border_size),
		Vector2(offset_x + nav_border_size, -nav_border_size)
		])
	navigation_region.navigation_polygon.add_outline(bounding_outline)
	navigation_region.bake_navigation_polygon()
	
	await(get_tree().process_frame)
	world_gen_done.emit()
