extends Control
## Minimapa local do HUD. Desenha a malha viaria existente sem segunda camera,
## viewport ou textura: custo fixo e baixo mesmo nos presets mais modestos.

const MAP_RANGE := 190.0
const REFRESH := 0.10
const ACCENT := Color(0.98, 0.67, 0.12, 1.0)
const ROAD := Color(0.52, 0.54, 0.53, 0.72)
const ROAD_EDGE := Color(0.16, 0.17, 0.17, 0.95)

var player: Node3D = null
var objective_position := Vector3.ZERO
var has_objective := false
var streets_x: Array[float] = []
var streets_z: Array[float] = []
var _refresh_timer := 0.0
var _background := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.bg_color = Color(0.045, 0.05, 0.049, 0.90)
	_background.border_color = Color(0.38, 0.39, 0.38, 0.82)
	_background.set_border_width_all(1)
	_background.corner_radius_top_left = 7
	_background.corner_radius_top_right = 7
	_background.corner_radius_bottom_left = 7
	_background.corner_radius_bottom_right = 7
	_background.shadow_color = Color(0, 0, 0, 0.42)
	_background.shadow_size = 7
	_find_street_grid()
	queue_redraw()

func set_player(value: Node) -> void:
	player = value as Node3D
	queue_redraw()

func set_objective(position: Vector3, active: bool) -> void:
	objective_position = position
	has_objective = active
	queue_redraw()

func has_street_grid() -> bool:
	return not streets_x.is_empty() and not streets_z.is_empty()

func _find_street_grid() -> void:
	if has_street_grid():
		return
	var streets := get_tree().root.find_child("CityStreets", true, false)
	if streets == null:
		return
	for value in streets.get("streets_x"):
		streets_x.append(float(value))
	for value in streets.get("streets_z"):
		streets_z.append(float(value))

func _tracking_node() -> Node3D:
	var vehicle: Node = GameManager.active_vehicle
	if vehicle != null and is_instance_valid(vehicle) and vehicle.get("driver") != null:
		return vehicle as Node3D
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	return player

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH:
		return
	_refresh_timer = 0.0
	_find_street_grid()
	queue_redraw()

func _map_rect() -> Rect2:
	return Rect2(Vector2(10.0, 25.0), Vector2(size.x - 20.0, size.y - 42.0))

func _world_offset(world_position: Vector3, origin: Vector3) -> Vector2:
	var rect := _map_rect()
	var scale_factor := minf(rect.size.x, rect.size.y) / (MAP_RANGE * 2.0)
	# -Z e o norte visual do mapa; +Z desce na tela.
	return Vector2(world_position.x - origin.x, world_position.z - origin.z) * scale_factor

func objective_map_position() -> Vector2:
	var rect := _map_rect()
	var center := rect.get_center()
	var tracked := _tracking_node()
	if tracked == null:
		return center
	var offset := _world_offset(objective_position, tracked.global_position)
	var limit := minf(rect.size.x, rect.size.y) * 0.5 - 7.0
	if offset.length() > limit:
		offset = offset.normalized() * limit
	return center + offset

func district_name(world_position: Vector3) -> String:
	if absf(world_position.x) <= 130.0 and absf(world_position.z) <= 130.0:
		return "CENTRO"
	if absf(world_position.x) > absf(world_position.z):
		return "ZONA LESTE" if world_position.x > 0.0 else "ZONA OESTE"
	return "ZONA SUL" if world_position.z > 0.0 else "ZONA NORTE"

func _draw() -> void:
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var tracked := _tracking_node()
	var district := "LOCALIZANDO"
	if tracked != null:
		district = district_name(tracked.global_position)
	draw_string(font, Vector2(12.0, 17.0), "MAPA  ·  " + district,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.82, 0.83, 0.80))
	draw_string(font, Vector2(size.x - 21.0, 17.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, ACCENT)

	var rect := _map_rect()
	draw_rect(rect, Color(0.075, 0.082, 0.08, 0.94), true)
	if tracked == null:
		return
	var center := rect.get_center()
	var scale_factor := minf(rect.size.x, rect.size.y) / (MAP_RANGE * 2.0)
	# Contorno primeiro e pista por cima: a grade continua legivel sem competir
	# com o marcador e sem precisar reproduzir cada tile 3D.
	for road_z in streets_x:
		var y := center.y + (road_z - tracked.global_position.z) * scale_factor
		if y >= rect.position.y and y <= rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), ROAD_EDGE, 5.0)
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), ROAD, 2.0)
	for road_x in streets_z:
		var x := center.x + (road_x - tracked.global_position.x) * scale_factor
		if x >= rect.position.x and x <= rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), ROAD_EDGE, 5.0)
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), ROAD, 2.0)

	if has_objective:
		var marker := objective_map_position()
		draw_line(center, marker, Color(ACCENT, 0.42), 1.5)
		draw_circle(marker, 6.0, Color(0.08, 0.09, 0.08, 1.0))
		draw_circle(marker, 4.0, ACCENT)

	var forward := -tracked.global_transform.basis.z
	var direction := Vector2(forward.x, forward.z).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector2(0.0, -1.0)
	var side := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([
		center + direction * 9.0,
		center - direction * 6.0 + side * 5.0,
		center - direction * 6.0 - side * 5.0,
	])
	draw_colored_polygon(points, Color(0.94, 0.95, 0.91))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]),
		Color(0.02, 0.025, 0.025, 1.0), 1.5)
