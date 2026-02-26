extends Node
## Sprite atlas helper - provides textures for characters and entities.
## Autoloaded as "SpriteAtlas"

enum Rogues {
	RANGER,
	MAGE,
	WARRIOR,
	ROGUE
}

# Preload the player texture atlas
var player_texture: Texture2D = preload("res://assets/Pixel Art Top Down - Basic v1.2.3/Texture/TX Player.png")

# Each character is 16x16 in a grid, arranged in rows
const SPRITE_SIZE := Vector2(16, 16)
const SPRITES_PER_ROW := 4


## Get a texture region for a specific rogue class
func get_rogue_texture(rogue_type: Rogues) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = player_texture
	
	# Calculate region based on character type
	# Assuming characters are arranged horizontally in the first row
	var col := int(rogue_type) % SPRITES_PER_ROW
	var row := int(rogue_type) / SPRITES_PER_ROW
	
	atlas.region = Rect2(
		col * SPRITE_SIZE.x,
		row * SPRITE_SIZE.y,
		SPRITE_SIZE.x,
		SPRITE_SIZE.y
	)
	
	return atlas


## Get a bard texture (using a specific sprite from the sheet)
func get_bard_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = player_texture
	
	# Use a different character for the bard (e.g., second row, first column)
	atlas.region = Rect2(0, SPRITE_SIZE.y, SPRITE_SIZE.x, SPRITE_SIZE.y)
	
	return atlas
