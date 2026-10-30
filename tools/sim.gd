extends SceneTree
## Balance check: plays several runs in a row with a simple automatic manager.
## godot --headless --path . -s tools/sim.gd -- [runs] [seed]

const Data = preload("res://scripts/data.gd")
const RunState = preload("res://scripts/run_state.gd")
const Meta = preload("res://scripts/meta.gd")

const BUILD_ORDER := ["stadium", "training_ground", "shop", "marketing", "coaching", "academy", "medical"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 3
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 7
	var verbose := args.has("v")
	var meta := Meta.new()
	for i in runs:
		var run := RunState.new()
		run.setup(meta.mods(), "Sim FC", rng.randi())
		run.set_ticket_mult(1.25)
		var last_year := 0
		while not run.ended:
			_manage(run)
			run.advance_week()
			if run.year != last_year and run.week == 1:
				last_year = run.year
				var h: Dictionary = run.history[-1] if not run.history.is_empty() else {}
				if verbose or run.year % 5 == 2 or run.year < 8:
					print("  y%3d tier %2d pos %s  money %8s  fans %7s  power %7s (league %7s)  train %s  wages %s/wk" % [
						run.year - 1, h.get("tier", 0), h.get("pos", "-"), Data.money(run.money), Data.big(run.fans),
						Data.big(RunState.power(run.team_stats())), Data.big(Data.strength(run.tier)),
						_levels(run), Data.money(run.wage_bill())])
				if verbose:
					var parts := []
					for k in run.last_season_ledger:
						parts.append("%s %s" % [k, Data.money(run.last_season_ledger[k])])
					print("        ", ", ".join(parts), "  | fac ", run.facilities.values())
			run.events.clear()
		meta.finish_run(run, rng)
		print("RUN %d: %s after %d years, best tier %d (%s), %d trophies, +%d shards" % [
			i + 1, run.end_reason, run.year, run.best_tier, Data.TIERS[run.best_tier].name, run.trophies.size(), meta.pending.shards])
		while not meta.pending.is_empty():
			meta.claim(meta.pending.choices[0])
		_spend(meta)
	quit()


func _levels(run) -> String:
	var parts := []
	for t in Data.TRAININGS:
		parts.append(str(run.trainings[t.id].level))
	return "/".join(parts)


func _manage(run) -> void:
	# Training: fill the slots with the lowest levels.
	var ids := Data.TRAININGS.map(func(t): return t.id)
	ids.sort_custom(func(a, b): return run.trainings[a].level < run.trainings[b].level)
	for id in ids:
		run.trainings[id].active = false
	for id in ids.slice(0, run.training_slots()):
		run.trainings[id].active = true
	var weekly: float = run.wage_bill() + run.training_bill() + run.upkeep_bill()
	# Transfers: replace the weakest starter when someone clearly better is affordable.
	var lu: Dictionary = run.lineup()
	for p in run.market.duplicate():
		var line: Array = lu[p.pos]
		var worst: float = line[-1].rating if line.size() == Data.FORMATION[p.pos] else 0.0
		if p.rating > worst * 1.15 and run.money > p.fee + weekly * 10:
			if run.squad.size() >= 16:
				_sell_worst_bench(run)
			if run.buy(p.id) == "":
				lu = run.lineup()
	# Facilities: build when we have a comfortable cushion.
	for id in BUILD_ORDER:
		var cost: float = Data.upgrade_cost(id, run.facilities[id])
		if run.money > cost * 2.5 + weekly * 8:
			run.upgrade_facility(id)
	if run.money < 0 and run.loan < run.max_loan():
		run.borrow()
	elif run.loan > 0 and run.money > run.loan_tranche() * 3:
		run.repay()


func _sell_worst_bench(run) -> void:
	var starters: Dictionary = run.starter_ids()
	var bench: Array = run.squad.filter(func(p): return not starters.has(p.id))
	if bench.is_empty():
		return
	bench.sort_custom(func(a, b): return a.rating < b.rating)
	run.sell(bench[0].id)


func _spend(meta) -> void:
	var bought := true
	while bought:
		bought = false
		var best := ""
		for u in Data.UPGRADES:
			if meta.can_buy(u.id) and (best == "" or meta.price(u.id) < meta.price(best)):
				best = u.id
		if best != "":
			meta.buy(best)
			bought = true
