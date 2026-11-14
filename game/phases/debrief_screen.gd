class_name DebriefScreen
extends Control

signal return_to_hangar

var _report: Dictionary = {}
var _credits_after: int = 0
var _loan_msg: String = ""

var _lbl_header: Label
var _good_box: VBoxContainer
var _bad_box: VBoxContainer
var _lbl_sources: Label


func setup(report: Dictionary, credits_after: int, loan_msg: String) -> void:
	_report = report
	_credits_after = credits_after
	_loan_msg = loan_msg
	_populate()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not _report.is_empty():
		_populate()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = SpaceTheme.COL_VOID
	add_child(bg)

	var root_v := VBoxContainer.new()
	root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_v.add_theme_constant_override("separation", 10)
	add_child(root_v)

	var top := PanelContainer.new()
	root_v.add_child(top)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	top.add_child(top_h)
	top_h.add_child(SpaceTheme.make_nasa_stripe(7.0, 22.0))
	_lbl_header = Label.new()
	_lbl_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceTheme.apply_mono(_lbl_header, 16)
	_lbl_header.add_theme_color_override("font_color", SpaceTheme.COL_AMBER)
	top_h.add_child(_lbl_header)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	root_v.add_child(cols)

	var p_good := PanelContainer.new()
	p_good.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p_good)
	var gv := VBoxContainer.new()
	p_good.add_child(gv)
	var gt := Label.new()
	gt.text = "QUE HICISTE BIEN (AUDITORIA FISICA)"
	gt.add_theme_color_override("font_color", SpaceTheme.COL_OK)
	gv.add_child(gt)
	_good_box = VBoxContainer.new()
	_good_box.add_theme_constant_override("separation", 6)
	gv.add_child(_good_box)

	var p_bad := PanelContainer.new()
	p_bad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p_bad)
	var bv := VBoxContainer.new()
	p_bad.add_child(bv)
	var bt := Label.new()
	bt.text = "QUE SALIO MAL / COMPROMISOS NASA"
	bt.add_theme_color_override("font_color", SpaceTheme.COL_TERRA)
	bv.add_child(bt)
	_bad_box = VBoxContainer.new()
	_bad_box.add_theme_constant_override("separation", 6)
	bv.add_child(_bad_box)

	var p_src := PanelContainer.new()
	root_v.add_child(p_src)
	var sh := HBoxContainer.new()
	p_src.add_child(sh)
	_lbl_sources = Label.new()
	_lbl_sources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_sources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SpaceTheme.apply_mono(_lbl_sources, 11)
	_lbl_sources.add_theme_color_override("font_color", SpaceTheme.COL_MUTED)
	sh.add_child(_lbl_sources)

	var btn_back := Button.new()
	btn_back.text = "VOLVER AL DIQUE SECO (CONSERVAR LVL)"
	SpaceTheme.style_cta_button(btn_back, SpaceTheme.COL_AMBER)
	btn_back.pressed.connect(func() -> void: return_to_hangar.emit())
	sh.add_child(btn_back)


func _populate() -> void:
	if _lbl_header == null or _report.is_empty():
		return
	_lbl_header.text = "REPORTE FINAL | RANGO: %s (%d pts) | Neto: $%d | Saldo Agencia: $%d %s" % [
		str(_report.get("grade", "C")),
		int(_report.get("score", 0)),
		int(_report.get("net_credits", 0)),
		_credits_after,
		_loan_msg,
	]

	for b: Container in [_good_box, _bad_box]:
		for ch: Node in b.get_children():
			ch.queue_free()

	for item: Dictionary in _report.get("good_items", []):
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "+ " + str(item.get("summary", ""))
		_good_box.add_child(l)
	for item: Dictionary in _report.get("bad_items", []):
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "- " + str(item.get("summary", ""))
		_bad_box.add_child(l)

	var src_lines: Array[String] = ["NASA & Partner Data activos en esta mision:"]
	for s: Dictionary in _report.get("nasa_sources", []):
		src_lines.append("%s (%s)" % [str(s.get("source", s.get("name", ""))), str(s.get("url", ""))])
	_lbl_sources.text = " | ".join(src_lines)
