class_name SpaceTheme
extends RefCounted

const COL_VOID := Color("#080c16")
const COL_CRT := Color("#05070b")
const COL_CHASSIS := Color("#0f1726")
const COL_RAISED := Color("#172236")
const COL_ACTIVE := Color("#1e2d47")
const COL_SEAM := Color("#24344d")
const COL_CREAM := Color("#f4ebd9")
const COL_MUTED := Color("#8b9bb4")
const COL_AMBER := Color("#f09c14")
const COL_CYAN := Color("#38bdf8")
const COL_TERRA := Color("#c83e2b")
const COL_OK := Color("#22c55e")

static var _sans_cache: SystemFont
static var _mono_cache: SystemFont


static func sans_font() -> SystemFont:
	if _sans_cache == null:
		_sans_cache = SystemFont.new()
		_sans_cache.font_names = PackedStringArray(["Noto Sans", "Inter", "Liberation Sans", "DejaVu Sans"])
	return _sans_cache


static func mono_font() -> SystemFont:
	if _mono_cache == null:
		_mono_cache = SystemFont.new()
		_mono_cache.font_names = PackedStringArray(["IBM Plex Mono", "Liberation Mono", "DejaVu Sans Mono"])
	return _mono_cache


static func apply_mono(ctrl: Control, font_size: int = 12) -> void:
	ctrl.add_theme_font_override("font", mono_font())
	ctrl.add_theme_font_size_override("font_size", maxi(font_size, 11))


static func make_nasa_stripe(bar_w: float = 8.0, bar_h: float = 24.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cols: Array[Color] = [COL_TERRA, COL_AMBER, COL_CREAM, COL_CYAN]
	for col: Color in cols:
		var r := ColorRect.new()
		r.color = col
		r.custom_minimum_size = Vector2(bar_w, bar_h)
		hb.add_child(r)
	return hb


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = sans_font()
	t.default_font_size = 13

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = COL_CHASSIS
	panel_sb.border_width_left = 1
	panel_sb.border_width_top = 1
	panel_sb.border_width_right = 1
	panel_sb.border_width_bottom = 1
	panel_sb.border_color = COL_SEAM
	panel_sb.corner_radius_top_left = 4
	panel_sb.corner_radius_top_right = 4
	panel_sb.corner_radius_bottom_left = 4
	panel_sb.corner_radius_bottom_right = 4
	panel_sb.content_margin_left = 10
	panel_sb.content_margin_right = 10
	panel_sb.content_margin_top = 8
	panel_sb.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	var btn_norm := StyleBoxFlat.new()
	btn_norm.bg_color = COL_RAISED
	btn_norm.border_width_left = 1
	btn_norm.border_width_top = 1
	btn_norm.border_width_right = 1
	btn_norm.border_width_bottom = 2
	btn_norm.border_color = COL_ACTIVE
	btn_norm.corner_radius_top_left = 4
	btn_norm.corner_radius_top_right = 4
	btn_norm.corner_radius_bottom_left = 4
	btn_norm.corner_radius_bottom_right = 4
	btn_norm.content_margin_left = 8
	btn_norm.content_margin_right = 8
	btn_norm.content_margin_top = 5
	btn_norm.content_margin_bottom = 5

	var btn_hover := btn_norm.duplicate() as StyleBoxFlat
	btn_hover.bg_color = COL_ACTIVE
	btn_hover.border_color = COL_CYAN

	var btn_pressed := btn_norm.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color("#283c5f")
	btn_pressed.border_color = COL_AMBER

	t.set_stylebox("normal", "Button", btn_norm)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_color("font_color", "Button", COL_CREAM)
	t.set_color("font_hover_color", "Button", Color("#ffffff"))
	t.set_color("font_color", "Label", COL_CREAM)
	t.set_font_size("font_size", "Button", 12)
	t.set_font_size("font_size", "Label", 13)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = COL_VOID
	pb_bg.corner_radius_top_left = 3
	pb_bg.corner_radius_top_right = 3
	pb_bg.corner_radius_bottom_left = 3
	pb_bg.corner_radius_bottom_right = 3

	var pb_fill := pb_bg.duplicate() as StyleBoxFlat
	pb_fill.bg_color = COL_CYAN
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	return t


static func style_cta_button(btn: Button, accent: Color = COL_AMBER) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = accent.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hov)
	var text_dark := accent == COL_AMBER or accent == COL_CYAN
	btn.add_theme_color_override("font_color", COL_VOID if text_dark else Color("#ffffff"))
	btn.add_theme_color_override("font_hover_color", COL_VOID if text_dark else Color("#ffffff"))
