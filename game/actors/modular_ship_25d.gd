class_name ModularShip25D
extends Node2D

signal room_clicked(room_id: StringName)
signal airlock_clicked(room_id: StringName)

const SHIP_SIZE := Vector2(160.0, 224.0)

const ROOM_RECTS: Dictionary = {
	&"sensors": Rect2(32, 14, 32, 48),
	&"helm": Rect2(64, 14, 64, 48),
	&"life_support": Rect2(12, 64, 34, 62),
	&"reactor": Rect2(46, 64, 52, 62),
	&"science_bay": Rect2(98, 64, 50, 62),
	&"engines": Rect2(34, 130, 92, 54),
}

const AIRLOCK_RECTS: Dictionary = {
	&"life_support": Rect2(0, 86, 16, 28),
	&"engines": Rect2(64, 180, 32, 14),
}

var _canvas_group: CanvasGroup
var _spr_aft_port: Sprite2D
var _spr_aft_stbd: Sprite2D
var _spr_hull: Sprite2D
var _spr_interior: Sprite2D
var _overlay_node: Node2D
var _spr_roof: Sprite2D
var _spr_port_nacelle: Sprite2D
var _spr_stbd_nacelle: Sprite2D
var _spr_bow: Sprite2D
var _spr_wing_port: Sprite2D
var _spr_wing_stbd: Sprite2D
var _spr_dorsal: Sprite2D

var _crew_sprites: Dictionary = {}
var _roof_target_alpha: float = 0.0
var _hazards: RoomHazards
var _crew_ctrl: CrewController
var _thruster_pulse: float = 0.0
var _tex_cache: Dictionary = {}


func _ready() -> void:
	_build_layers()


func _build_layers() -> void:
	_canvas_group = CanvasGroup.new()
	_canvas_group.fit_margin = 48.0
	_canvas_group.clear_margin = 48.0
	var sh := load("res://game/shaders/ship_outline_canvasgroup.gdshader") as Shader
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_canvas_group.material = mat
	add_child(_canvas_group)

	# Z = -1: Motores traseros remetidos 4px bajo el faldon
	_spr_aft_port = _make_sprite(Vector2(-26.0, 90.0), -1)
	_spr_aft_stbd = _make_sprite(Vector2(26.0, 90.0), -1)

	# Z = 0: Casco maestro + piso interior FTL
	_spr_hull = _make_sprite(Vector2.ZERO, 0)
	_spr_interior = _make_sprite(Vector2.ZERO, 0)
	_spr_interior.texture = _load_tex("res://assets/ship/interior_floor_6rooms.png")

	# Z = 1: Gondolas laterales babor y estribor
	_spr_port_nacelle = _make_sprite(Vector2(-86.0, -4.0), 1)
	_spr_stbd_nacelle = _make_sprite(Vector2(86.0, -4.0), 1)

	# Z = 2: Proa y alas articuladas
	_spr_bow = _make_sprite(Vector2(0.0, -106.0), 2)
	_spr_wing_port = _make_sprite(Vector2(-124.0, 8.0), 2)
	_spr_wing_stbd = _make_sprite(Vector2(124.0, 8.0), 2)
	_spr_wing_stbd.flip_h = true

	# Z = 3: Torreta dorsal y capa cutaway exterior
	_spr_dorsal = _make_sprite(Vector2(0.0, -6.0), 3)
	_spr_roof = _make_sprite(Vector2.ZERO, 3)
	_spr_roof.texture = _load_tex("res://assets/ship/roof_cutaway.png")

	# Capa de estado dinamico interior (estados de sala, fuego, brecha, crew)
	_overlay_node = _InteriorOverlay.new(self)
	_overlay_node.position = -SHIP_SIZE * 0.5
	_overlay_node.z_index = 2
	add_child(_overlay_node)

	for cid: StringName in CrewController.CREW_IDS:
		var sp := Sprite2D.new()
		sp.texture = _load_tex("res://assets/crew/crew_%s.png" % String(cid))
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index = 4
		_overlay_node.add_child(sp)
		_crew_sprites[cid] = sp


func _make_sprite(pos: Vector2, z: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.position = pos
	sp.z_index = z
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas_group.add_child(sp)
	return sp


func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_tex_cache[path] = tex
		return tex
	return null


func apply_build(build: ShipBuildState) -> void:
	var hull_lvl := clampi(build.hull_level, 1, 5)
	_spr_hull.texture = _load_tex("res://assets/ship/hull_base_lvl%d.png" % hull_lvl)

	var bow_slot: Dictionary = build.sockets[&"bow"]
	var bow_mod: Dictionary = ShipBuildState.MODULE_CATALOG[bow_slot["module"]]
	_spr_bow.texture = _load_tex("res://assets/modules/%s_lvl%d.png" % [bow_mod["sprite"], int(bow_slot["level"])])

	var port_slot: Dictionary = build.sockets[&"port_nacelle"]
	var port_mod: Dictionary = ShipBuildState.MODULE_CATALOG[port_slot["module"]]
	_spr_port_nacelle.texture = _load_tex("res://assets/modules/%s_lvl%d.png" % [port_mod["sprite"], int(port_slot["level"])])

	var stbd_slot: Dictionary = build.sockets[&"stbd_nacelle"]
	var stbd_mod: Dictionary = ShipBuildState.MODULE_CATALOG[stbd_slot["module"]]
	_spr_stbd_nacelle.texture = _load_tex("res://assets/modules/%s_lvl%d.png" % [stbd_mod["sprite"], int(stbd_slot["level"])])

	var wp_slot: Dictionary = build.sockets[&"wing_port"]
	var wp_mod: Dictionary = ShipBuildState.MODULE_CATALOG[wp_slot["module"]]
	_spr_wing_port.texture = _load_tex("res://assets/modules/%s_lvl%d.png" % [wp_mod["sprite"], int(wp_slot["level"])])

	var ws_slot: Dictionary = build.sockets[&"wing_stbd"]
	var ws_mod: Dictionary = ShipBuildState.MODULE_CATALOG[ws_slot["module"]]
	_spr_wing_stbd.texture = _load_tex("res://assets/modules/%s_lvl%d.png" % [ws_mod["sprite"], int(ws_slot["level"])])

	var dor_slot: Dictionary = build.sockets[&"dorsal_turret"]
	var dor_mod: Dictionary = ShipBuildState.MODULE_CATALOG[dor_slot["module"]]
	_spr_dorsal.texture = _load_tex("res://assets/modules/%s_lvl%d.png" % [dor_mod["sprite"], int(dor_slot["level"])])

	var aft_slot: Dictionary = build.sockets[&"aft_engines"]
	var aft_mod: Dictionary = ShipBuildState.MODULE_CATALOG[aft_slot["module"]]
	var aft_tex := _load_tex("res://assets/modules/%s_lvl%d.png" % [aft_mod["sprite"], int(aft_slot["level"])])
	_spr_aft_port.texture = aft_tex
	_spr_aft_stbd.texture = aft_tex


func set_cutaway_open(open: bool) -> void:
	_roof_target_alpha = 0.0 if open else 1.0


func bind_simulation(hazards: RoomHazards, crew_ctrl: CrewController) -> void:
	_hazards = hazards
	_crew_ctrl = crew_ctrl


func set_thruster_power(throttle: float) -> void:
	_thruster_pulse = clampf(throttle, 0.0, 1.0)


func _process(delta: float) -> void:
	if _spr_roof != null:
		_spr_roof.modulate.a = lerpf(_spr_roof.modulate.a, _roof_target_alpha, clampf(delta * 10.0, 0.0, 1.0))
	if _spr_interior != null:
		_spr_interior.visible = _spr_roof.modulate.a < 0.85
	if _overlay_node != null:
		_overlay_node.visible = _roof_target_alpha < 0.5
		if _crew_ctrl != null:
			for cid: StringName in CrewController.CREW_IDS:
				var sp := _crew_sprites.get(cid) as Sprite2D
				if sp != null:
					var c: Dictionary = _crew_ctrl.crew[cid]
					sp.position = c["pos"]
		_overlay_node.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _roof_target_alpha > 0.5:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos := to_local(get_global_mouse_position()) + SHIP_SIZE * 0.5
		for al_id: StringName in AIRLOCK_RECTS.keys():
			if (AIRLOCK_RECTS[al_id] as Rect2).has_point(local_pos):
				airlock_clicked.emit(al_id)
				return
		for rid: StringName in ROOM_RECTS.keys():
			if (ROOM_RECTS[rid] as Rect2).has_point(local_pos):
				room_clicked.emit(rid)
				return


class _InteriorOverlay extends Node2D:
	var _owner: ModularShip25D

	func _init(owner_node: ModularShip25D) -> void:
		_owner = owner_node

	func _draw() -> void:
		if _owner._hazards == null:
			return
		# Pluma de motor en popa segun acelerador
		if _owner._thruster_pulse > 0.05:
			var len_p := 12.0 + _owner._thruster_pulse * 26.0 + sin(Time.get_ticks_msec() * 0.03) * 4.0
			for mx: float in [54.0, 106.0]:
				draw_colored_polygon(
					PackedVector2Array([Vector2(mx - 6, 206), Vector2(mx + 6, 206), Vector2(mx, 206 + len_p)]),
					Color(0.96, 0.55, 0.12, 0.85)
				)

		for rid: StringName in ModularShip25D.ROOM_RECTS.keys():
			var r: Dictionary = _owner._hazards.get_room(rid)
			var rect: Rect2 = ModularShip25D.ROOM_RECTS[rid]
			var hp := float(r.get("hp", 1.0))
			var o2 := float(r.get("oxygen", 1.0))
			var fire := float(r.get("fire", 0.0))
			var breach := float(r.get("breach", 0.0))

			# Nivel de oxigeno sutil en piso (azul frio -> rojo hipoxia)
			if o2 < 0.35:
				draw_rect(rect.grow(-2.0), Color(0.78, 0.24, 0.17, (0.35 - o2) * 1.3), true)
			if hp < 0.70:
				var border_col := Color("#f09c14") if hp >= 0.35 else Color("#c83e2b")
				draw_rect(rect, border_col, false, 1.5)
			if fire > 0.05:
				var fcol := Color(0.98, 0.45, 0.09, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.02))
				draw_circle(rect.get_center() + Vector2(-6, 4), 8.0 * clampf(fire + 0.4, 0.4, 1.0), fcol)
			if breach > 0.05:
				draw_rect(rect.grow(-3.0), Color("#38bdf8"), false, 1.5)
			if bool(r.get("critical_active", false)):
				var t := float(r.get("critical_timer_s", 0.0))
				draw_rect(rect.grow(1.0), Color("#c83e2b"), false, 2.0)
				var bar_w := rect.size.x * clampf(t / RoomHazards.CRITICAL_WINDOW_S, 0.0, 1.0)
				draw_rect(Rect2(rect.position.x, rect.position.y - 4, bar_w, 3), Color("#c83e2b"), true)

		# Indicador de esclusas (Airlocks)
		for al_id: StringName in ModularShip25D.AIRLOCK_RECTS.keys():
			var arect: Rect2 = ModularShip25D.AIRLOCK_RECTS[al_id]
			var is_open := bool(_owner._hazards.get_room(al_id).get("airlock_open", false))
			var acol := Color("#c83e2b") if is_open else Color("#f09c14")
			draw_rect(arect, acol, is_open, 1.5)
