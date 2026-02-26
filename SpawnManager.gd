extends Node
class_name SpawnManager

@export var player: Player

# Spawn Components (our enemy trigger)
@export var encounter_actor_scene: PackedScene

# Bit mask for detecting walls on collision layer 2
@export var wall_collision_mask: int = 1 << 1

# How often to update spawns
@export var update_interval: float = 0.25

var _spawn_zones: Array[SpawnZone] = []
var _zone_spawn_timer := {}
var _spawned_enemies_by_zone := {}
var _seconds_until_next_tick := 0.0

func _ready() -> void:
	_find_zones_in_scene()

func _process(delta: float) -> void:
	_seconds_until_next_tick -= delta
	if _seconds_until_next_tick > 0.0:
		return
	_seconds_until_next_tick = update_interval
	
	if player == null or encounter_actor_scene == null:
		return
	
	# Update each zone's enemy spawns
	for zone in _spawn_zones:
		_tick_zone(zone, update_interval)

func _find_zones_in_scene() -> void:
	_spawn_zones.clear()

	for node in get_tree().get_nodes_in_group("spawn_zones"):
		if node is SpawnZone:
			var zone := node as SpawnZone
			_spawn_zones.append(zone)

			if not _zone_spawn_timer.has(zone.zone_id):
				_zone_spawn_timer[zone.zone_id] = 0.0
			if not _spawned_enemies_by_zone.has(zone.zone_id):
				_spawned_enemies_by_zone[zone.zone_id] = Array()
	
	print("Spawn zones found: ", _spawn_zones.size())
	for z in _spawn_zones:
		print("-", z.zone_id, " groups=", z.get_groups())


func _tick_zone(zone: SpawnZone, dt: float) -> void:
	#  despawn far enemies 
	_cleanup_freed_actor_refs(zone)
	_despawn_enemies_far_from_player(zone)

	# Only spawn if player is currently inside this zone
	if not zone.is_player_inside:
		return

	# Tick down the zone’s timer
	var remaining := float(_zone_spawn_timer.get(zone.zone_id, 0.0))
	remaining -= dt
	_zone_spawn_timer[zone.zone_id] = remaining

	# If timer not ready, stop
	if remaining > 0.0:
		return

	# Reset timer and attempt spawn
	_zone_spawn_timer[zone.zone_id] = zone.spawn_interval
	_try_spawn_one_encounter(zone)


func _try_spawn_one_encounter(zone: SpawnZone) -> void:
	if _count_alive_enemies_in_zone(zone) >= zone.max_alive:
		return

	var encounter_id := zone.pick_encounter_id()
	if encounter_id.is_empty():
		return

	var spawn_position := _find_valid_spawn_position(zone)
	if not spawn_position.is_finite():
		return

	var spawned_node := encounter_actor_scene.instantiate()
	if spawned_node == null:
		return

	(spawned_node as Node2D).global_position = spawn_position

	if spawned_node is EncounterActor:
		var actor := spawned_node as EncounterActor
		actor.encounter_id = encounter_id
		actor.one_time = false

	get_tree().current_scene.add_child(spawned_node)
	_track_spawned_actor(zone, spawned_node)


func _track_spawned_actor(zone: SpawnZone, actor_node: Node) -> void:
	(_spawned_enemies_by_zone[zone.zone_id] as Array).append(weakref(actor_node))


func _cleanup_freed_actor_refs(zone: SpawnZone) -> void:
	var refs: Array = _spawned_enemies_by_zone[zone.zone_id]
	var alive_refs: Array = []

	for wr in refs:
		if wr is WeakRef and wr.get_ref() != null:
			alive_refs.append(wr)

	_spawned_enemies_by_zone[zone.zone_id] = alive_refs


func _count_alive_enemies_in_zone(zone: SpawnZone) -> int:
	return (_spawned_enemies_by_zone[zone.zone_id] as Array).size()


func _despawn_enemies_far_from_player(zone: SpawnZone) -> void:
	var refs: Array = _spawned_enemies_by_zone[zone.zone_id]
	for wr in refs:
		var actor_node: Node = (wr as WeakRef).get_ref()
		if actor_node == null:
			continue
		if actor_node is Node2D:
			var actor_pos := (actor_node as Node2D).global_position
			if actor_pos.distance_to(player.global_position) > zone.despawn_distance_pixels:
				(actor_node as Node).queue_free()

func _find_valid_spawn_position(zone: SpawnZone) -> Vector2:
	for _i in range(zone.sample_attempts):
		var candidate: Vector2 = _random_point_inside_zone(zone)
		if _is_spawn_position_valid(candidate, zone):
			return candidate
	return Vector2.INF


func _is_spawn_position_valid(world_pos: Vector2, zone: SpawnZone) -> bool:
	if world_pos.distance_to(player.global_position) < zone.min_dist_from_player_pixels:
		return false
	
	var space : PhysicsDirectSpaceState2D = get_tree().current_scene.get_world_2d().direct_space_state

	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = wall_collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var hits := space.intersect_point(params, 8)
	return hits.is_empty()


func _random_point_inside_zone(zone: SpawnZone) -> Vector2:
	var collision_shape := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return zone.global_position

	if collision_shape.shape is RectangleShape2D:
		var rect := collision_shape.shape as RectangleShape2D
		var half := rect.size * 0.5
		var local := Vector2(
			randf_range(-half.x, half.x),
			randf_range(-half.y, half.y)
		)
		return zone.to_global(collision_shape.position + local)

	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		var r := circle.radius * sqrt(randf())
		var theta := randf() * TAU
		var local := Vector2(cos(theta), sin(theta)) * r
		return zone.to_global(collision_shape.position + local)

	return zone.global_position
