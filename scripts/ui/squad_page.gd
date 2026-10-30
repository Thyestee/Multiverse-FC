extends VBoxContainer
## The squad: who starts, what they cost, and selling players.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

const WIDTHS := [36, 46, 0, 44, 70, 80, 90, 90, 100, 150]
const ORDER := {"GK": 0, "DEF": 1, "MID": 2, "ATK": 3}

var _header: Label
var _lines: Label
var _list: VBoxContainer
var _sell_buttons := []
var _signature := ""


func _init() -> void:
	name = "Squad"
	add_theme_constant_override("separation", 10)
	var top := S.hbox(16)
	_header = S.label("", 18)
	top.add_child(_header)
	top.add_child(S.spacer())
	_lines = S.label("", 14, S.MUTED)
	top.add_child(_lines)
	add_child(top)
	var hint := S.label("The best fit player in each position starts (4-3-3: 1 GK, 4 DEF, 3 MID, 3 ATK). Young players grow towards their potential each season; players over 30 decline. Wages are fixed when a player signs.", 13, S.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var cols := ["XI", "Pos", "Name", "Age", "Rating", "Potential", "Wage/wk", "Value", "Status", ""]
	var head := []
	for c in cols:
		head.append(S.caption(c))
	add_child(S.row(head, WIDTHS, Color(0, 0, 0, 0)))
	_list = S.vbox(4)
	add_child(S.scroll(_list))


func refresh(run) -> void:
	_header.text = "%d / %d players · wages %s per week" % [run.squad.size(), Data.SQUAD_MAX, Data.money(run.wage_bill())]
	var stats: Dictionary = run.team_stats()
	_lines.text = "Attack %s · Midfield %s · Defence %s · Goalkeeping %s" % [Data.big(stats.ATK), Data.big(stats.MID), Data.big(stats.DEF), Data.big(stats.GK)]
	var sig := "%d|%d" % [run.squad_rev, run.squad.reduce(func(a, p): return a + p.injured, 0)]
	if sig != _signature:
		_signature = sig
		_rebuild(run)
	for b in _sell_buttons:
		b.disabled = run.squad.size() <= 11


func _rebuild(run) -> void:
	S.clear(_list)
	_sell_buttons.clear()
	var starters: Dictionary = run.starter_ids()
	var players: Array = run.squad.duplicate()
	players.sort_custom(func(a, b):
		if a.pos != b.pos:
			return ORDER[a.pos] < ORDER[b.pos]
		return a.rating > b.rating
	)
	for p in players:
		var starting: bool = starters.has(p.id)
		var growth: bool = p.potential > p.rating * 1.02 and p.age <= 24
		var status := "Injured %dw" % p.injured if p.injured > 0 else ("Starting" if starting else "Bench")
		var sell := S.button("Sell %s" % Data.money(run.sell_price(p)), _sell.bind(p.id))
		_sell_buttons.append(sell)
		var cells := [
			S.label("XI" if starting else "", 13, S.GOLD),
			S.label(p.pos, 14, S.pos_color(p.pos)),
			S.label(p.name, 15),
			S.label(str(p.age), 14),
			S.label(Data.big(p.rating), 15, S.TEXT),
			S.label(Data.big(p.potential) if growth else "-", 14, S.GREEN if growth else S.MUTED),
			S.label(Data.money(p.wage), 14, S.MUTED),
			S.label(Data.money(run.player_value(p)), 14, S.MUTED),
			S.label(status, 14, S.RED if p.injured > 0 else (S.GREEN if starting else S.MUTED)),
			sell,
		]
		_list.add_child(S.row(cells, WIDTHS, S.PANEL_2 if starting else S.ROW))


func _sell(id: int) -> void:
	Game.act(Game.run.sell(id))
