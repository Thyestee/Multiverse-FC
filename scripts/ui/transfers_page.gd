extends VBoxContainer
## The transfer market: buying players and scouting for more.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

const WIDTHS := [46, 0, 44, 70, 80, 180, 110, 90, 90, 150]

var _scout: Button
var _status: Label
var _list: VBoxContainer
var _buy_buttons := {}  # player id -> button
var _signature := ""


func _init() -> void:
	name = "Transfers"
	add_theme_constant_override("separation", 10)
	var top := S.hbox(16)
	_status = S.label("", 18)
	top.add_child(_status)
	top.add_child(S.spacer())
	_scout = S.button("", func(): Game.act(Game.run.scout()), S.BLUE)
	top.add_child(_scout)
	add_child(top)
	var hint := S.label("New players arrive at the start of each season and in week 9. Some come from the league above: stronger, and pricier. \"vs your XI\" compares a player with your weakest starter in that position.", 13, S.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var head := []
	for c in ["Pos", "Name", "Age", "Rating", "Potential", "From", "vs your XI", "Wage/wk", "Fee", ""]:
		head.append(S.caption(c))
	add_child(S.row(head, WIDTHS, Color(0, 0, 0, 0)))
	_list = S.vbox(4)
	add_child(S.scroll(_list))


func refresh(run) -> void:
	_status.text = "%d players on the market · squad %d / %d" % [run.market.size(), run.squad.size(), Data.SQUAD_MAX]
	_scout.text = "Scout new players (%s)" % Data.money(run.scout_cost())
	_scout.disabled = run.money < run.scout_cost()
	var sig := "%d|%d" % [run.market_rev, run.squad_rev]
	if sig != _signature:
		_signature = sig
		_rebuild(run)
	for p in run.market:
		if _buy_buttons.has(p.id):
			_buy_buttons[p.id].disabled = run.money < p.fee or run.squad.size() >= Data.SQUAD_MAX


func _rebuild(run) -> void:
	S.clear(_list)
	_buy_buttons.clear()
	if run.market.is_empty():
		_list.add_child(S.label("Nobody is for sale right now. Scout for more players or wait for the next window.", 15, S.MUTED))
		return
	var lu: Dictionary = run.lineup()
	for p in run.market:
		var line: Array = lu[p.pos]
		var full: bool = line.size() == Data.FORMATION[p.pos]
		var worst: float = line[-1].rating if full else 0.0
		var compare := "New starter"
		var color := S.GREEN
		if full:
			var diff: float = p.rating / worst - 1.0
			compare = "%+d%%" % int(round(diff * 100))
			color = S.GREEN if diff > 0.0 else S.RED
		var from := int(p.get("from", run.tier))
		var growth: bool = p.potential > p.rating * 1.02 and p.age <= 24
		var buy := S.button("Buy", func(): Game.act(Game.run.buy(p.id)), S.GREEN)
		_buy_buttons[p.id] = buy
		var cells := [
			S.label(p.pos, 14, S.pos_color(p.pos)),
			S.label(p.name, 15),
			S.label(str(p.age), 14),
			S.label(Data.big(p.rating), 15),
			S.label(Data.big(p.potential) if growth else "-", 14, S.GREEN if growth else S.MUTED),
			S.label(Data.TIERS[from].name, 13, S.VIOLET if from > run.tier else S.MUTED),
			S.label(compare, 14, color),
			S.label(Data.money(p.wage), 14, S.MUTED),
			S.label(Data.money(p.fee), 15, S.GOLD),
			buy,
		]
		_list.add_child(S.row(cells, WIDTHS))
