extends VBoxContainer
## Money: balance, ticket pricing, loans, and where the money came from and went.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

var _balance: Label
var _net: Label
var _debt: Label
var _slider: HSlider
var _price: Label
var _crowd: Label
var _loan: Label
var _borrow: Button
var _repay: Button
var _costs: VBoxContainer
var _week: VBoxContainer
var _season: VBoxContainer
var _last_season: VBoxContainer


func _init() -> void:
	name = "Finances"
	var body := S.hbox(14)
	add_child(S.scroll(body))
	var left := S.vbox(14)
	var right := S.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	body.add_child(right)

	var c := S.card("Balance")
	_balance = S.label("", 30, S.GOLD)
	_net = S.label("", 15)
	_debt = S.label("", 14, S.RED)
	_debt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c[1].add_child(_balance)
	c[1].add_child(_net)
	c[1].add_child(_debt)
	left.add_child(c[0])

	c = S.card("Ticket prices")
	_price = S.label("", 18)
	c[1].add_child(_price)
	_slider = HSlider.new()
	_slider.min_value = 0.4
	_slider.max_value = 2.2
	_slider.step = 0.05
	_slider.custom_minimum_size.y = 24
	_slider.value_changed.connect(_on_price)
	c[1].add_child(_slider)
	_crowd = S.label("", 14, S.MUTED)
	_crowd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c[1].add_child(_crowd)
	var tip := S.label("Cheaper tickets fill more seats; dearer ones earn more per fan. Home league games earn the full gate, cup games half.", 13, S.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c[1].add_child(tip)
	left.add_child(c[0])

	c = S.card("Bank loan")
	_loan = S.label("", 15)
	_loan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c[1].add_child(_loan)
	var h := S.hbox(10)
	_borrow = S.button("", func(): Game.act(Game.run.borrow()), S.BLUE)
	_repay = S.button("", func(): Game.act(Game.run.repay()))
	h.add_child(_borrow)
	h.add_child(_repay)
	c[1].add_child(h)
	left.add_child(c[0])

	c = S.card("Fixed weekly costs")
	_costs = c[1]
	left.add_child(c[0])

	c = S.card("Last week")
	_week = c[1]
	right.add_child(c[0])
	c = S.card("This season so far")
	_season = c[1]
	right.add_child(c[0])
	c = S.card("Last season")
	_last_season = c[1]
	right.add_child(c[0])


func refresh(run) -> void:
	_balance.text = Data.money(run.money)
	_balance.add_theme_color_override("font_color", S.GOLD if run.money >= 0 else S.RED)
	var net := _sum(run.last_week)
	_net.text = "Last week: %s%s" % ["+" if net >= 0 else "", Data.money(net)]
	_net.add_theme_color_override("font_color", S.GREEN if net >= 0 else S.RED)
	if run.debt_weeks > 0:
		_debt.text = "In debt for %d week(s). The club goes bankrupt after %d weeks in a row below $0." % [run.debt_weeks, run.bankrupt_after()]
	else:
		_debt.text = ""
	_slider.set_value_no_signal(run.ticket_mult)
	_update_tickets(run)
	_loan.text = "Owed: %s of %s allowed in this league. Interest 1.2%% per week." % [Data.money(run.loan), Data.money(run.max_loan())]
	_borrow.text = "Borrow %s" % Data.money(run.loan_tranche())
	_borrow.disabled = run.loan + run.loan_tranche() > run.max_loan() + 0.01
	var repay := minf(run.loan_tranche(), run.loan)
	_repay.text = "Repay %s" % Data.money(repay)
	_repay.disabled = repay <= 0.0 or run.money < repay
	_fill(_costs, {
		"Wages": -run.wage_bill(), "Training": -run.training_bill(), "Upkeep": -run.upkeep_bill(),
		"Loan interest": -run.loan * 0.012,
	})
	_fill(_week, run.last_week)
	_fill(_season, run.season_ledger)
	_fill(_last_season, run.last_season_ledger)


func _on_price(value: float) -> void:
	Game.run.set_ticket_mult(value)
	_update_tickets(Game.run)


func _update_tickets(run) -> void:
	_price.text = "%s per ticket (%d%% of the usual price in this league)" % [Data.money(run.ticket_price()), int(round(run.ticket_mult * 100))]
	_crowd.text = "Expected crowd %s of %s seats · %s fans · gate %s per home game" % [
		Data.big(run.attendance()), Data.big(run.capacity()), Data.big(run.fans), Data.money(run.gate_income())]


func _sum(ledger: Dictionary) -> float:
	var total := 0.0
	for k in ledger:
		if k != "Loans":
			total += ledger[k]
	return total


func _fill(box: VBoxContainer, ledger: Dictionary) -> void:
	while box.get_child_count() > 1:
		var c := box.get_child(box.get_child_count() - 1)
		box.remove_child(c)
		c.queue_free()
	if ledger.is_empty():
		box.add_child(S.label("Nothing yet.", 14, S.MUTED))
		return
	var keys := ledger.keys()
	keys.sort_custom(func(a, b): return ledger[a] > ledger[b])
	for k in keys:
		var h := S.hbox(10)
		var n := S.label(k, 14)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var v: float = ledger[k]
		h.add_child(S.label(("+" if v > 0 else "") + Data.money(v), 14, S.GREEN if v > 0 else S.RED))
		box.add_child(h)
	var total := _sum(ledger)
	var t := S.hbox(10)
	var tl := S.label("Total (excluding loans)", 14, S.MUTED)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(tl)
	t.add_child(S.label(("+" if total > 0 else "") + Data.money(total), 15, S.GREEN if total >= 0 else S.RED))
	box.add_child(t)
