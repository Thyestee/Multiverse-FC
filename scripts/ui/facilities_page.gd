extends VBoxContainer
## Facilities: one-off upgrades that cost upkeep every week.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

const BLURB := {
	"stadium": "More seats for paying fans.",
	"training_ground": "Every drill gains experience faster.",
	"coaching": "Run more drills at the same time.",
	"shop": "Shirts, scarves and mugs. Earns more per fan every week.",
	"marketing": "Grows the number of fans the club can attract.",
	"academy": "Brings through a cheap young player each season.",
	"medical": "Fewer injuries, and quicker recoveries.",
}

var _header: Label
var _rows := {}


func _init() -> void:
	name = "Facilities"
	add_theme_constant_override("separation", 10)
	_header = S.label("", 18)
	add_child(_header)
	var list := S.vbox(8)
	for f in Data.FACILITIES:
		list.add_child(_make_row(f))
	add_child(S.scroll(list))


func _make_row(f: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(S.ROW, 8, 12))
	var h := S.hbox(16)
	panel.add_child(h)
	var info := S.vbox(2)
	info.custom_minimum_size.x = 300
	var title := S.label(f.name, 18)
	info.add_child(title)
	var blurb := S.label(BLURB[f.id], 13, S.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(blurb)
	h.add_child(info)
	var lvl := S.label("", 16, S.GOLD)
	lvl.custom_minimum_size.x = 90
	lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lvl)
	var effect := S.vbox(2)
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var now := S.label("", 15)
	var next := S.label("", 13, S.GREEN)
	effect.add_child(now)
	effect.add_child(next)
	h.add_child(effect)
	var upkeep := S.label("", 13, S.MUTED)
	upkeep.custom_minimum_size.x = 150
	upkeep.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	upkeep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(upkeep)
	var up := S.button("", func(): Game.act(Game.run.upgrade_facility(f.id)), S.GREEN)
	up.custom_minimum_size.x = 190
	up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(up)
	_rows[f.id] = {"level": lvl, "now": now, "next": next, "upkeep": upkeep, "button": up}
	return panel


func refresh(run) -> void:
	_header.text = "Facility upkeep %s per week · stadium holds %s, last crowd about %s" % [
		Data.money(run.upkeep_bill()), Data.big(run.capacity()), Data.big(run.attendance())]
	for f in Data.FACILITIES:
		var r: Dictionary = _rows[f.id]
		var lvl: int = run.facilities[f.id]
		var maxed: bool = lvl >= f.max
		r.level.text = "Level %d" % lvl
		r.now.text = Data.facility_effect(f.id, lvl)
		r.next.text = "Max level" if maxed else "Next: " + Data.facility_effect(f.id, lvl + 1)
		r.upkeep.text = "Upkeep %s/wk" % Data.money(Data.upkeep(f.id, lvl)) if lvl > 0 else "No upkeep"
		var cost := Data.upgrade_cost(f.id, lvl)
		r.button.text = "Maxed" if maxed else "Upgrade %s" % Data.money(cost)
		r.button.disabled = maxed or run.money < cost
