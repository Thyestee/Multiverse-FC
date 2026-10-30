extends RefCounted
## One run: a club climbing from its starting league towards the Multiverse Premier
## within a hundred years. Pure game logic with no nodes, so it also runs headless.

const Data = preload("res://scripts/data.gd")

var rng := RandomNumberGenerator.new()
var mods := {}  # meta-progression bonuses, fixed for the whole run
var club_name := ""
var year := 1
var week := 1
var tier := 0
var start_tier := 0
var best_tier := 0
var money := 0.0
var loan := 0.0
var debt_weeks := 0
var fans := 0.0
var ticket_mult := 1.0
var squad: Array = []
var market: Array = []
var next_id := 1
var trainings := {}  # id -> {level, xp, active}
var facilities := {}  # id -> level
var league := {}  # {teams, table, fixtures}
var cup := {}  # {alive, round, out, winner}
var form: Array = []  # "W" / "D" / "L", newest last
var trophies: Array = []
var history: Array = []
var last_match := {}
var ledger := {}  # this week, category -> amount (income positive)
var last_week := {}
var season_ledger := {}
var last_season_ledger := {}
var events: Array = []  # [text, kind] not yet shown
var ended := false
var end_reason := ""
var seasons_played := 0
var season_weeks := 0  # weeks counted in season_ledger
var squad_rev := 0
var market_rev := 0


func setup(meta_mods: Dictionary, name: String, seed_value: int) -> void:
	rng.seed = seed_value
	mods = meta_mods
	club_name = name
	tier = int(mods.get("start_tier", 0))
	start_tier = tier
	best_tier = tier
	money = 5000.0 * Data.economy(tier) * mods.start_money
	fans = 300.0 * pow(1.336, tier) * mods.fans
	for t in Data.TRAININGS:
		trainings[t.id] = {"level": 0, "xp": 0.0, "active": false}
	trainings.shooting.active = true
	trainings.defending.active = true
	for f in Data.FACILITIES:
		facilities[f.id] = 0
	_make_starting_squad()
	_new_league()
	_refresh_market()
	_event("%s are founded in the %s. Win it, climb the leagues, and become the best club in the multiverse within %d years." % [club_name, tier_name(), Data.MAX_YEARS], "gold")


# --- Queries -----------------------------------------------------------------

func tier_name(t := -1) -> String:
	return Data.TIERS[tier if t < 0 else t].name


func level(training_id: String) -> int:
	return trainings[training_id].level


func fac(id: String) -> int:
	return facilities[id]


func training_slots() -> int:
	return 2 + fac("coaching") / 2 + int(mods.slots)


func active_trainings() -> int:
	var n := 0
	for t in trainings.values():
		if t.active:
			n += 1
	return n


func xp_rate() -> float:
	return 10.0 * (1.0 + 0.2 * fac("training_ground")) * mods.xp


func form_score() -> float:
	if form.is_empty():
		return 0.5
	var pts := 0
	for r in form:
		pts += 3 if r == "W" else (1 if r == "D" else 0)
	return pts / (3.0 * form.size())


func morale() -> float:
	return 0.94 + 0.12 * form_score()


func capacity() -> float:
	return Data.capacity(fac("stadium"))


func ticket_price() -> float:
	return Data.fair_price(tier) * ticket_mult


func attendance() -> float:
	var demand := clampf(1.25 - 0.5 * ticket_mult, 0.15, 1.0)
	return minf(capacity(), fans * demand)


func gate_income() -> float:
	return attendance() * ticket_price() * mods.income * mods.ticket


func fan_target() -> float:
	return Data.fan_base(tier) * (1.0 + 0.1 * fac("marketing")) * mods.fans


func wage_bill() -> float:
	var total := 0.0
	for p in squad:
		total += p.wage
	return total


func training_bill() -> float:
	var total := 0.0
	for id in trainings:
		if trainings[id].active:
			total += Data.training_cost(trainings[id].level, tier)
	return total


func upkeep_bill() -> float:
	var total := 0.0
	for id in facilities:
		total += Data.upkeep(id, facilities[id])
	return total


func loan_tranche() -> float:
	return 4000.0 * Data.economy(tier)


func max_loan() -> float:
	return Data.LOAN_TRANCHES * loan_tranche()


func bankrupt_after() -> int:
	return Data.BANKRUPT_WEEKS + int(mods.iron)


func lineup() -> Dictionary:
	var result := {}
	for pos in Data.POSITIONS:
		var fit := squad.filter(func(p): return p.pos == pos and p.injured <= 0)
		fit.sort_custom(func(a, b): return a.rating > b.rating)
		result[pos] = fit.slice(0, Data.FORMATION[pos])
	return result


func starter_ids() -> Dictionary:
	var ids := {}
	var lu := lineup()
	for pos in lu:
		for p in lu[pos]:
			ids[p.id] = true
	return ids


func _line_rating(pos: String, lu: Dictionary) -> float:
	var need: int = Data.FORMATION[pos]
	var total := 0.0
	for p in lu[pos]:
		total += p.rating
	# Missing players are covered by local amateurs.
	total += (need - lu[pos].size()) * Data.strength(tier) * 0.25
	return total / need


func team_stats() -> Dictionary:
	var lu := lineup()
	var whole := pow(1.015, level("tactics")) * pow(1.005, level("fitness")) * morale()
	return {
		"ATK": _line_rating("ATK", lu) * pow(1.03, level("shooting")) * whole * mods.atk,
		"MID": _line_rating("MID", lu) * pow(1.03, level("passing")) * whole * mods.mid,
		"DEF": _line_rating("DEF", lu) * pow(1.03, level("defending")) * whole * mods.def,
		"GK": _line_rating("GK", lu) * pow(1.04, level("keeping")) * whole * mods.gk,
	}


static func power(stats: Dictionary) -> float:
	return 0.3 * stats.ATK + 0.3 * stats.MID + 0.28 * stats.DEF + 0.12 * stats.GK


func team_stats_of(index: int) -> Dictionary:
	return team_stats() if index == 0 else league.teams[index]


func team_name(index: int) -> String:
	return club_name if index == 0 else league.teams[index].name


## Team indices sorted by points, goal difference, then goals scored.
func standings() -> Array:
	var order := range(Data.LEAGUE_SIZE)
	var table: Array = league.table
	order.sort_custom(func(a, b):
		var ta: Dictionary = table[a]
		var tb: Dictionary = table[b]
		if ta.pts != tb.pts:
			return ta.pts > tb.pts
		if ta.gf - ta.ga != tb.gf - tb.ga:
			return ta.gf - ta.ga > tb.gf - tb.ga
		return ta.gf > tb.gf
	)
	return order


func league_position() -> int:
	return standings().find(0) + 1


## The next match this club plays, or {} in the off-season.
func next_fixture() -> Dictionary:
	for w in range(week, Data.LAST_MATCH_WEEK + 1):
		if w in Data.CUP_WEEKS:
			if cup.out or cup.alive.size() < 2:
				continue
			var i: int = cup.alive.find(0)
			var other: int = cup.alive[i + 1] if i % 2 == 0 else cup.alive[i - 1]
			return {"week": w, "opponent": other, "home": i % 2 == 0, "comp": "Cup " + Data.CUP_ROUNDS[cup.round]}
		var r := Data.LEAGUE_WEEKS.find(w)
		if r >= 0:
			for pair in league.fixtures[r]:
				if pair[0] == 0 or pair[1] == 0:
					return {"week": w, "opponent": pair[1] if pair[0] == 0 else pair[0], "home": pair[0] == 0, "comp": "League"}
	return {}


# --- Weekly simulation -------------------------------------------------------

func advance_week() -> void:
	if ended:
		return
	ledger = {}
	season_weeks += 1
	_train()
	_weekly_money()
	for p in squad:
		if p.injured > 0:
			p.injured -= 1
			if p.injured == 0:
				_event("%s is fit again." % p.name, "info")
	if week in Data.CUP_WEEKS:
		_play_cup_round()
	elif week in Data.LEAGUE_WEEKS:
		_play_league_round()
	if week == 9:
		_refresh_market()
		_event("The mid-season transfer window brings new players to the market.", "info")
	if week == Data.LAST_MATCH_WEEK:
		_end_season()
	if ended:
		last_week = ledger
		return
	_check_debt()
	last_week = ledger
	if ended:
		return
	week += 1
	if week > Data.WEEKS_PER_SEASON:
		week = 1
		year += 1
		_event("Year %d begins in the %s." % [year, tier_name()], "info")


func _add(category: String, amount: float) -> void:
	if is_zero_approx(amount):
		return
	money += amount
	ledger[category] = ledger.get(category, 0.0) + amount
	season_ledger[category] = season_ledger.get(category, 0.0) + amount


func _train() -> void:
	var rate := xp_rate()
	for t in Data.TRAININGS:
		var tr: Dictionary = trainings[t.id]
		if not tr.active:
			continue
		_add("Training", -Data.training_cost(tr.level, tier))
		_gain_xp(t, rate)


func _gain_xp(t: Dictionary, amount: float) -> void:
	var tr: Dictionary = trainings[t.id]
	tr.xp += amount
	while tr.xp >= Data.training_xp_needed(tr.level):
		tr.xp -= Data.training_xp_needed(tr.level)
		tr.level += 1
		_event("%s training reached level %d." % [t.name, tr.level], "good")


func _weekly_money() -> void:
	var e := Data.economy(tier)
	_add("Sponsors", 150.0 * e * (0.75 + 0.5 * form_score()) * mods.income * mods.sponsor)
	_add("TV rights", 250.0 * e * mods.income * mods.sponsor)
	_add("Club shop", fans * 0.04 * (1.0 + 0.4 * fac("shop")) * pow(1.06, tier) * mods.income)
	_add("Wages", -wage_bill())
	_add("Upkeep", -upkeep_bill())
	if loan > 0.0:
		_add("Loan interest", -loan * 0.012)


func _check_debt() -> void:
	if money >= 0.0:
		if debt_weeks > 0:
			_event("The club is out of debt.", "good")
		debt_weeks = 0
		return
	_add("Overdraft interest", money * 0.02)
	debt_weeks += 1
	var left := bankrupt_after() - debt_weeks
	if left <= 0:
		_event("The bank calls in the debt. %s go bankrupt." % club_name, "bad")
		_end("bankrupt")
	else:
		_event("In debt! Get back above $0 within %d week%s or the club goes bankrupt." % [left, "" if left == 1 else "s"], "bad")


# --- Matches -----------------------------------------------------------------

func _poisson(lambda: float) -> int:
	var limit := exp(-lambda)
	var k := 0
	var p := rng.randf()
	while p > limit:
		k += 1
		p *= rng.randf()
	return k


func _simulate(home: Dictionary, away: Dictionary) -> Array:
	var mh := pow(home.MID, 2.0)
	var ma := pow(away.MID, 2.0)
	var poss: float = mh / (mh + ma)
	var lh: float = 2.7 * poss * pow(home.ATK / (0.65 * away.DEF + 0.35 * away.GK), 0.9) * 1.08
	var la: float = 2.7 * (1.0 - poss) * pow(away.ATK / (0.65 * home.DEF + 0.35 * home.GK), 0.9)
	return [_poisson(clampf(lh, 0.05, 7.0)), _poisson(clampf(la, 0.05, 7.0))]


func _play_league_round() -> void:
	var r := Data.LEAGUE_WEEKS.find(week)
	for pair in league.fixtures[r]:
		var h: int = pair[0]
		var a: int = pair[1]
		var g := _simulate(team_stats_of(h), team_stats_of(a))
		_record(h, g[0], g[1])
		_record(a, g[1], g[0])
		if h == 0 or a == 0:
			_our_match(h, a, g, "League")


func _record(team: int, scored: int, conceded: int) -> void:
	var row: Dictionary = league.table[team]
	row.p += 1
	row.gf += scored
	row.ga += conceded
	if scored > conceded:
		row.w += 1
		row.pts += 3
	elif scored == conceded:
		row.d += 1
		row.pts += 1
	else:
		row.l += 1


func _play_cup_round() -> void:
	if cup.alive.size() < 2:
		return
	var round_name: String = Data.CUP_ROUNDS[cup.round]
	var winners := []
	for i in range(0, cup.alive.size(), 2):
		var h: int = cup.alive[i]
		var a: int = cup.alive[i + 1]
		var g := _simulate(team_stats_of(h), team_stats_of(a))
		var winner := h if g[0] > g[1] else a
		var pens := ""
		if g[0] == g[1]:
			winner = h if rng.randf() < 0.5 else a
			pens = " (%s win on penalties)" % team_name(winner)
		winners.append(winner)
		if h == 0 or a == 0:
			_our_match(h, a, g, "Cup " + round_name, pens)
			var e := Data.economy(tier)
			if winner == 0:
				_add("Prize money", 1500.0 * e * mods.income)
			else:
				cup.out = true
				_event("Knocked out of the cup in the %s." % round_name, "bad")
	cup.alive = winners
	cup.round += 1
	if winners.size() == 1:
		cup.winner = winners[0]
		if cup.winner == 0:
			_add("Prize money", 6000.0 * Data.economy(tier) * mods.income)
			trophies.append("%s Cup, year %d" % [tier_name(), year])
			_event("CUP WINNERS! %s lift the %s Cup." % [club_name, tier_name()], "gold")
		else:
			_event("%s win the cup." % team_name(cup.winner), "info")


func _our_match(h: int, a: int, g: Array, comp: String, note := "") -> void:
	var home := h == 0
	var ours: int = g[0] if home else g[1]
	var theirs: int = g[1] if home else g[0]
	var result := "W" if ours > theirs else ("D" if ours == theirs else "L")
	if note != "":
		result = "W" if note.begins_with(" (" + club_name) else "L"
	form.append(result)
	if form.size() > 5:
		form.pop_front()
	var e := Data.economy(tier)
	if result == "W":
		_add("Match bonuses", 300.0 * e * mods.income)
	elif ours == theirs:
		_add("Match bonuses", 100.0 * e * mods.income)
	if home:
		_add("Tickets", gate_income())
	elif comp != "League":
		_add("Tickets", gate_income() * 0.5)
	_update_fans(result if note == "" else ("D" if ours == theirs else result))
	var scorers := _scorers(ours)
	last_match = {
		"comp": comp, "home": team_name(h), "away": team_name(a), "hg": g[0], "ag": g[1],
		"result": result, "scorers": scorers, "note": note, "week": week, "year": year,
	}
	var text := "%s: %s %d-%d %s%s" % [comp, team_name(h), g[0], g[1], team_name(a), note]
	if not scorers.is_empty():
		text += ". Goals: " + ", ".join(scorers)
	_event(text, "match_" + result)
	_injuries()


func _scorers(goals: int) -> Array:
	var lu := lineup()
	var pool := []
	for pos in lu:
		var weight: int = {"ATK": 6, "MID": 3, "DEF": 1, "GK": 0}[pos]
		for p in lu[pos]:
			for i in weight:
				pool.append(p.name.get_slice(" (", 0).get_slice(" ", 1))
	var list := []
	var minutes := []
	for i in goals:
		minutes.append(rng.randi_range(1, 90))
	minutes.sort()
	for m in minutes:
		list.append("%s %d'" % [pool[rng.randi() % pool.size()] if not pool.is_empty() else "Amateur", m])
	return list


func _update_fans(result: String) -> void:
	# Fans drift towards what the league and the club's marketing can support;
	# winning brings in up to 30% more, losing drives them away.
	var target := fan_target() * (1.3 if result == "W" else (1.0 if result == "D" else 0.85))
	var rate: float = 0.06 * mods.fan_growth if target > fans else 0.03
	fans = maxf(fans + (target - fans) * rate, 50.0)


func _injuries() -> void:
	var chance: float = 0.03 * pow(0.96, level("fitness")) * (1.0 - 0.06 * fac("medical")) * mods.injury
	for id in starter_ids():
		if rng.randf() < chance:
			var p := player_by_id(id)
			p.injured = maxi(1, int(round(rng.randi_range(1, 6) * (1.0 - 0.06 * fac("medical")))))
			_event("%s is injured for %d week%s." % [p.name, p.injured, "" if p.injured == 1 else "s"], "bad")


# --- Season ------------------------------------------------------------------

func _end_season() -> void:
	var order := standings()
	var pos := order.find(0) + 1
	var row: Dictionary = league.table[0]
	_add("Prize money", (9 - pos) * 1500.0 * Data.economy(tier) * mods.income)
	seasons_played += 1
	var cup_result := "Winners" if cup.winner == 0 else ("Out" if cup.out else "-")
	history.append({"year": year, "tier": tier, "pos": pos, "pts": row.pts, "cup": cup_result, "fans": fans})
	last_season_ledger = season_ledger
	season_ledger = {}
	season_weeks = 0
	if pos == 1:
		trophies.append("%s title, year %d" % [tier_name(), year])
		_event("CHAMPIONS! %s win the %s." % [club_name, tier_name()], "gold")
		if tier == Data.TOP_TIER:
			_event("%s are the best club in the multiverse!" % club_name, "gold")
			_end("victory")
			return
	else:
		_event("Season over: %s finish %s in the %s." % [club_name, ordinal(pos), tier_name()], "info")
	if pos <= 2 and tier < Data.TOP_TIER:
		tier += 1
		fans *= 1.1
		_event("PROMOTED to the %s (%s)." % [tier_name(), Data.TIERS[tier].realm], "gold")
	elif pos >= Data.LEAGUE_SIZE - 1 and tier > 0:
		tier -= 1
		fans *= 0.9
		_event("Relegated to the %s." % tier_name(), "bad")
	best_tier = maxi(best_tier, tier)
	_age_squad()
	_youth_intake()
	if year >= Data.MAX_YEARS:
		_event("A hundred years have passed. The club's story ends here.", "bad")
		_end("century")
		return
	_new_league()
	_refresh_market()


func _age_squad() -> void:
	for p in squad.duplicate():
		p.age += 1
		if p.age <= 24 and p.potential > p.rating:
			p.rating += (p.potential - p.rating) * 0.4
		elif p.age >= 31:
			p.rating *= rng.randf_range(0.88, 0.95)
		if p.age >= 34 and rng.randf() < 0.35 + (p.age - 34) * 0.25:
			squad.erase(p)
			_event("%s retires at %d." % [p.name, p.age], "info")
	squad_rev += 1


func _youth_intake() -> void:
	var lvl := fac("academy")
	if lvl <= 0:
		return
	if squad.size() >= Data.SQUAD_MAX:
		_event("The academy has a promising youngster, but the squad is full.", "info")
		return
	var b := Data.strength(tier)
	var pos: String = Data.pick(["GK", "DEF", "DEF", "MID", "MID", "ATK", "ATK"], rng)
	var p := _make_player(pos, b * (0.35 + 0.05 * lvl) * rng.randf_range(0.9, 1.1), rng.randi_range(16, 17), tier)
	p.potential = b * (0.85 + 0.07 * lvl) * rng.randf_range(0.9, 1.2)
	squad.append(p)
	squad_rev += 1
	_event("Academy graduate %s (%s) joins the first team." % [p.name, p.pos], "good")


func _new_league() -> void:
	var teams := [{"name": club_name}]
	var used := {club_name: true}
	var b := Data.strength(tier) * pow(1.015, year)
	while teams.size() < Data.LEAGUE_SIZE:
		var n := Data.club_name(tier, rng)
		if used.has(n):
			continue
		used[n] = true
		var s := b * rng.randf_range(0.7, 1.3)
		teams.append({
			"name": n, "ATK": s * rng.randf_range(0.88, 1.12), "MID": s * rng.randf_range(0.88, 1.12),
			"DEF": s * rng.randf_range(0.88, 1.12), "GK": s * rng.randf_range(0.88, 1.12),
		})
	var table := []
	for i in Data.LEAGUE_SIZE:
		table.append({"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0})
	league = {"teams": teams, "table": table, "fixtures": _round_robin(Data.LEAGUE_SIZE)}
	var alive := range(Data.LEAGUE_SIZE)
	for i in range(alive.size() - 1, 0, -1):  # shuffle with the run's own generator so reloads replay the same
		var j := rng.randi_range(0, i)
		var tmp = alive[i]
		alive[i] = alive[j]
		alive[j] = tmp
	cup = {"alive": alive, "round": 0, "out": false, "winner": -1}


## Double round robin (circle method): one array of [home, away] pairs per round.
func _round_robin(n: int) -> Array:
	var teams := range(n)
	var rounds := []
	for r in n - 1:
		var pairs := []
		for i in n / 2:
			var a: int = teams[i]
			var b: int = teams[n - 1 - i]
			pairs.append([a, b] if (r + i) % 2 == 0 else [b, a])
		rounds.append(pairs)
		teams = [teams[0], teams[n - 1]] + teams.slice(1, n - 1)
	var second := []
	for pairs in rounds:
		second.append(pairs.map(func(p): return [p[1], p[0]]))
	return rounds + second


# --- Players -----------------------------------------------------------------

func _make_player(pos: String, rating: float, age: int, from_tier: int) -> Dictionary:
	var p := {
		"id": next_id, "name": Data.player_name(from_tier, rng), "pos": pos, "age": age,
		"rating": rating, "potential": rating, "wage": Data.wage_for(rating) * mods.wage, "injured": 0,
	}
	next_id += 1
	if age <= 23:
		p.potential = rating * rng.randf_range(1.05, 1.5)
	return p


func _make_starting_squad() -> void:
	var b: float = Data.strength(tier) * mods.golden
	var counts := {"GK": 2, "DEF": 5, "MID": 5, "ATK": 4}
	for pos in counts:
		for i in counts[pos]:
			squad.append(_make_player(pos, b * rng.randf_range(0.78, 1.0), rng.randi_range(18, 32), tier))


func player_by_id(id: int) -> Dictionary:
	for p in squad:
		if p.id == id:
			return p
	return {}


func player_value(p: Dictionary) -> float:
	return Data.value_for(p.rating, p.age, p.potential)


func sell_price(p: Dictionary) -> float:
	return 0.6 * player_value(p)


func _refresh_market() -> void:
	market.clear()
	for i in 6 + int(mods.scout_n):
		var r := rng.randf()
		var t := tier
		if r < 0.2:
			t = mini(tier + 1, Data.TOP_TIER)
		elif r < 0.3:
			t = maxi(tier - 1, 0)
		var pos: String = Data.pick(["GK", "DEF", "DEF", "DEF", "MID", "MID", "MID", "ATK", "ATK", "ATK"], rng)
		var p := _make_player(pos, Data.strength(t) * rng.randf_range(0.75, 1.15) * mods.scout_q, rng.randi_range(17, 33), t)
		p.fee = player_value(p) * (1.0 + 0.1 * (t - tier))
		p.from = t
		market.append(p)
	market.sort_custom(func(a, b): return a.rating > b.rating)
	market_rev += 1


func scout_cost() -> float:
	return 300.0 * Data.economy(tier)


# --- Player actions ----------------------------------------------------------
# Each returns "" on success, or a reason it can't be done.

func buy(id: int) -> String:
	var p := {}
	for m in market:
		if m.id == id:
			p = m
	if p.is_empty():
		return "That player is gone."
	if squad.size() >= Data.SQUAD_MAX:
		return "The squad is full (%d players). Sell someone first." % Data.SQUAD_MAX
	if money < p.fee:
		return "Not enough money."
	_add("Transfers", -p.fee)
	market.erase(p)
	p.erase("fee")
	p.erase("from")
	squad.append(p)
	squad_rev += 1
	market_rev += 1
	_event("Signed %s (%s, rating %s) for %s." % [p.name, p.pos, Data.big(p.rating), Data.money(player_value(p))], "good")
	return ""


func sell(id: int) -> String:
	var p := player_by_id(id)
	if p.is_empty():
		return "That player is gone."
	if squad.size() <= 11:
		return "You need at least 11 players."
	var price := sell_price(p)
	_add("Transfers", price)
	squad.erase(p)
	squad_rev += 1
	_event("Sold %s for %s." % [p.name, Data.money(price)], "info")
	return ""


func scout() -> String:
	if money < scout_cost():
		return "Not enough money."
	_add("Scouting", -scout_cost())
	_refresh_market()
	return ""


func toggle_training(id: String) -> String:
	var tr: Dictionary = trainings[id]
	if not tr.active and active_trainings() >= training_slots():
		return "All training slots are in use. Upgrade the coaching staff for more."
	tr.active = not tr.active
	return ""


func intensive(id: String) -> String:
	var tr: Dictionary = trainings[id]
	var cost := Data.intensive_cost(tr.level, tier)
	if money < cost:
		return "Not enough money."
	_add("Training", -cost)
	for t in Data.TRAININGS:
		if t.id == id:
			_gain_xp(t, Data.training_xp_needed(tr.level) * 0.5)
	return ""


func upgrade_facility(id: String) -> String:
	var f := Data.facility(id)
	if facilities[id] >= f.max:
		return "Already at the maximum level."
	var cost := Data.upgrade_cost(id, facilities[id])
	if money < cost:
		return "Not enough money."
	_add("Facilities", -cost)
	facilities[id] += 1
	_event("%s upgraded to level %d." % [f.name, facilities[id]], "good")
	return ""


func borrow() -> String:
	if loan + loan_tranche() > max_loan() + 0.01:
		return "The bank won't lend more than %s in this league." % Data.money(max_loan())
	loan += loan_tranche()
	_add("Loans", loan_tranche())
	return ""


func repay() -> String:
	var amount := minf(loan_tranche(), loan)
	if amount <= 0.0:
		return "No loan to repay."
	if money < amount:
		return "Not enough money."
	loan -= amount
	_add("Loans", -amount)
	return ""


func set_ticket_mult(value: float) -> void:
	ticket_mult = clampf(value, 0.4, 2.2)


func abandon() -> void:
	_event("The board walks away from %s." % club_name, "bad")
	_end("abandoned")


func _end(reason: String) -> void:
	ended = true
	end_reason = reason


func _event(text: String, kind: String) -> void:
	events.append([text, kind, year, week])


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


# --- Saving ------------------------------------------------------------------

const SAVED := ["mods", "club_name", "year", "week", "tier", "start_tier", "best_tier", "money", "loan",
	"debt_weeks", "fans", "ticket_mult", "squad", "market", "next_id", "trainings", "facilities", "league",
	"cup", "form", "trophies", "history", "last_match", "last_week", "season_ledger", "last_season_ledger",
	"ended", "end_reason", "seasons_played", "season_weeks"]


func to_dict() -> Dictionary:
	var d := {"rng_seed": str(rng.seed), "rng_state": str(rng.state)}
	for key in SAVED:
		d[key] = get(key)
	return d


func from_dict(d: Dictionary) -> void:
	for key in SAVED:
		if d.has(key):
			set(key, d[key])
	rng.seed = int(d.get("rng_seed", "1"))
	rng.state = int(d.get("rng_state", "1"))
	# JSON turns every number into a float; put the integers back.
	for key in ["year", "week", "tier", "start_tier", "best_tier", "debt_weeks", "next_id", "seasons_played", "season_weeks"]:
		set(key, int(get(key)))
	for p in squad + market:
		for k in ["id", "age", "injured"]:
			p[k] = int(p[k])
	for id in trainings:
		trainings[id].level = int(trainings[id].level)
	for id in facilities:
		facilities[id] = int(facilities[id])
	for row in league.table:
		for k in row:
			row[k] = int(row[k])
	league.fixtures = league.fixtures.map(func(r): return r.map(func(p): return [int(p[0]), int(p[1])]))
	cup.alive = cup.alive.map(func(i): return int(i))
	cup.round = int(cup.round)
	cup.winner = int(cup.winner)
	squad_rev += 1
	market_rev += 1
