extends VBoxContainer
## Training: each drill levels up over time while it's active, for a weekly cost.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

var _header: Label
var _rows := {}  # training id -> {level, xp, bar, cost, toggle, intensive}


func _init() -> void:
	name = "Training"
	add_theme_constant_override("separation", 10)
	_header = S.label("", 18)
	add_child(_header)
	var hint := S.label("Active drills gain experience every week and level up when the bar fills. Each level makes the team permanently stronger for the rest of the run, but higher levels cost more per week. An intensive session fills half a level at once.", 13, S.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var list := S.vbox(8)
	for t in Data.TRAININGS:
		list.add_child(_make_row(t))
	add_child(S.scroll(list))


func _make_row(t: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(S.ROW, 8, 12))
	var h := S.hbox(16)
	panel.add_child(h)
	var info := S.vbox(2)
	info.custom_minimum_size.x = 250
	info.add_child(S.label(t.name, 18))
	var desc := S.label(t.desc, 13, S.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 250
	info.add_child(desc)
	h.add_child(info)
	var mid := S.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := S.hbox(8)
	var lvl := S.label("", 16, S.GOLD)
	top.add_child(lvl)
	top.add_child(S.spacer())
	var xp := S.label("", 13, S.MUTED)
	top.add_child(xp)
	mid.add_child(top)
	var color := S.pos_color(t.line) if t.line != "" else S.VIOLET
	var bar := S.bar(color, 14)
	mid.add_child(bar)
	h.add_child(mid)
	var cost := S.label("", 14, S.MUTED)
	cost.custom_minimum_size.x = 130
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cost)
	var toggle := S.button("", func(): Game.act(Game.run.toggle_training(t.id)))
	toggle.custom_minimum_size.x = 120
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(toggle)
	var intensive := S.button("", func(): Game.act(Game.run.intensive(t.id)), S.GOLD)
	intensive.custom_minimum_size.x = 210
	intensive.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(intensive)
	_rows[t.id] = {"level": lvl, "xp": xp, "bar": bar, "cost": cost, "toggle": toggle, "intensive": intensive}
	return panel


func refresh(run) -> void:
	_header.text = "Training slots %d / %d · %s XP per week · drills cost %s per week" % [
		run.active_trainings(), run.training_slots(), Data.big(run.xp_rate()), Data.money(run.training_bill())]
	for id in _rows:
		var r: Dictionary = _rows[id]
		var tr: Dictionary = run.trainings[id]
		r.level.text = "Level %d" % tr.level
		r.cost.text = ("%s / week" % Data.money(Data.training_cost(tr.level, run.tier))) if tr.active else "Resting"
		r.toggle.text = "Training" if tr.active else "Start"
		if tr.active:
			S.tint(r.toggle, S.GREEN)
		else:
			for s in ["normal", "hover", "pressed"]:
				r.toggle.remove_theme_stylebox_override(s)
		r.toggle.disabled = not tr.active and run.active_trainings() >= run.training_slots()
		var cost := Data.intensive_cost(tr.level, run.tier)
		r.intensive.text = "Intensive session %s" % Data.money(cost)
		r.intensive.disabled = run.money < cost
	live(run, Game.week_fraction())


func live(run, fraction: float) -> void:
	var rate: float = run.xp_rate()
	for id in _rows:
		var r: Dictionary = _rows[id]
		var tr: Dictionary = run.trainings[id]
		var need := Data.training_xp_needed(tr.level)
		var xp: float = tr.xp + (rate * fraction if tr.active else 0.0)
		r.bar.value = clampf(xp / need, 0.0, 1.0)
		r.xp.text = "%s / %s XP" % [Data.big(minf(xp, need)), Data.big(need)]
