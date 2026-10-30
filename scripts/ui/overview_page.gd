extends VBoxContainer
## Club overview: next match, last result, season, strength and the road ahead.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")
const RunState = preload("res://scripts/run_state.gd")

var _body: HBoxContainer
var _week_bar: ProgressBar


func _init() -> void:
	name = "Overview"
	_body = S.hbox(14)
	add_child(S.scroll(_body))


func refresh(run) -> void:
	S.clear(_body)
	var left := S.vbox(14)
	var right := S.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(left)
	_body.add_child(right)
	left.add_child(_next_match(run))
	left.add_child(_last_match(run))
	left.add_child(_season(run))
	right.add_child(_strength(run))
	right.add_child(_ladder(run))


func live(_run, fraction: float) -> void:
	if is_instance_valid(_week_bar):
		_week_bar.value = fraction


func _next_match(run) -> Control:
	var c := S.card("Next match")
	var v: VBoxContainer = c[1]
	var fx: Dictionary = run.next_fixture()
	if fx.is_empty():
		v.add_child(S.label("Off-season. The new season starts next week.", 18))
	else:
		var ours := RunState.power(run.team_stats())
		var theirs := RunState.power(run.team_stats_of(fx.opponent))
		var title := S.label("%s  vs  %s" % [run.club_name, run.team_name(fx.opponent)] if fx.home else "%s  vs  %s" % [run.team_name(fx.opponent), run.club_name], 22)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(title)
		var when: int = fx.week - run.week
		var when_text := "this week" if when == 0 else ("next week" if when == 1 else "in %d weeks" % when)
		v.add_child(S.label("%s · %s · %s" % [fx.comp, "Home" if fx.home else "Away", when_text], 14, S.MUTED))
		var top := maxf(ours, theirs)
		for entry in [[run.club_name, ours, S.GREEN], [run.team_name(fx.opponent), theirs, S.RED]]:
			var h := S.hbox(10)
			var n := S.label(entry[0], 14)
			n.custom_minimum_size.x = 210
			n.clip_text = true
			h.add_child(n)
			var b := S.bar(entry[2], 12)
			b.value = entry[1] / top
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
			var num := S.label(Data.big(entry[1]), 14)
			num.custom_minimum_size.x = 60
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(num)
			v.add_child(h)
		var ratio := ours / theirs
		var verdict := "Clear favourites" if ratio > 1.3 else ("Slight favourites" if ratio > 1.08 else ("Even match" if ratio > 0.92 else ("Underdogs" if ratio > 0.75 else "Huge underdogs")))
		v.add_child(S.label(verdict, 14, S.GREEN if ratio > 1.08 else (S.TEXT if ratio > 0.92 else S.RED)))
	var h2 := S.hbox(10)
	h2.add_child(S.label("Week %d" % run.week, 13, S.MUTED))
	_week_bar = S.bar(S.BLUE, 6)
	_week_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_week_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h2.add_child(_week_bar)
	v.add_child(h2)
	return c[0]


func _last_match(run) -> Control:
	var c := S.card("Last result")
	var v: VBoxContainer = c[1]
	var m: Dictionary = run.last_match
	if m.is_empty():
		v.add_child(S.label("No matches played yet.", 15, S.MUTED))
		return c[0]
	var color: Color = {"W": S.GREEN, "D": S.TEXT, "L": S.RED}[m.result]
	var score := S.label("%s  %d - %d  %s" % [m.home, m.hg, m.ag, m.away], 20, color)
	score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(score)
	var info := "%s, year %d week %d%s" % [m.comp, m.year, m.week, m.note]
	v.add_child(S.label(info, 13, S.MUTED))
	if not m.scorers.is_empty():
		var g := S.label("Goals: " + ", ".join(m.scorers), 14)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(g)
	var form := S.hbox(6)
	form.add_child(S.label("Form", 13, S.MUTED))
	for r in run.form:
		var chip := S.label(" %s " % r, 13, Color.BLACK)
		var bg: Color = {"W": S.GREEN, "D": S.MUTED, "L": S.RED}[r]
		chip.add_theme_stylebox_override("normal", S.box(bg, 4, 2))
		form.add_child(chip)
	v.add_child(form)
	return c[0]


func _season(run) -> Control:
	var c := S.card("Season %d · %s" % [run.year, run.tier_name()])
	var v: VBoxContainer = c[1]
	var pos: int = run.league_position()
	var order: Array = run.standings()
	var row: Dictionary = run.league.table[0]
	var color := S.GREEN if pos <= 2 else (S.RED if pos >= 7 and run.tier > 0 else S.TEXT)
	v.add_child(S.label("%s place · %d points from %d games" % [RunState.ordinal(pos), row.pts, row.p], 20, color))
	var second: Dictionary = run.league.table[order[1]]
	var note := ""
	if run.tier == Data.TOP_TIER:
		note = "Win this league to become the best club in the multiverse."
	elif pos <= 2:
		note = "In the promotion places. The top two go up."
	else:
		note = "%d points behind the promotion places. The top two go up." % (second.pts - row.pts)
	if run.tier > 0:
		note += " The bottom two go down."
	var nl := S.label(note, 14, S.MUTED)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	var cup := ""
	if run.cup.winner == 0:
		cup = "Cup: winners!"
	elif run.cup.out:
		cup = "Cup: knocked out"
	elif run.cup.winner >= 0:
		cup = "Cup: won by " + run.team_name(run.cup.winner)
	else:
		cup = "Cup: into the " + Data.CUP_ROUNDS[run.cup.round]
	v.add_child(S.label(cup, 15))
	v.add_child(S.label("Trophies won this run: %d" % run.trophies.size(), 15, S.GOLD))
	return c[0]


func _strength(run) -> Control:
	var c := S.card("Team strength vs league average")
	var v: VBoxContainer = c[1]
	var stats: Dictionary = run.team_stats()
	var avg := {"ATK": 0.0, "MID": 0.0, "DEF": 0.0, "GK": 0.0}
	for i in range(1, Data.LEAGUE_SIZE):
		for k in avg:
			avg[k] += run.league.teams[i][k] / (Data.LEAGUE_SIZE - 1)
	var names := {"ATK": "Attack", "MID": "Midfield", "DEF": "Defence", "GK": "Goalkeeping"}
	for k in ["ATK", "MID", "DEF", "GK"]:
		var h := S.hbox(10)
		var n := S.label(names[k], 14)
		n.custom_minimum_size.x = 110
		h.add_child(n)
		var ratio: float = stats[k] / avg[k]
		var b := S.bar(S.pos_color(k), 12)
		b.value = clampf(ratio / 2.0, 0.0, 1.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		var num := S.label("%s (%d%%)" % [Data.big(stats[k]), int(round(ratio * 100))], 14, S.GREEN if ratio >= 1.0 else S.RED)
		num.custom_minimum_size.x = 120
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(num)
		v.add_child(h)
	v.add_child(S.label("Bars are full at twice the league average. Morale from form: %d%%." % int(round(run.morale() * 100)), 13, S.MUTED))
	return c[0]


func _ladder(run) -> Control:
	var c := S.card("Road to the multiverse")
	var v: VBoxContainer = c[1]
	v.add_theme_constant_override("separation", 3)
	for i in range(Data.TOP_TIER, -1, -1):
		var t: Dictionary = Data.TIERS[i]
		var here: bool = i == run.tier
		var color := S.GOLD if here else (S.TEXT if i <= run.best_tier else S.MUTED.darkened(0.2))
		var h := S.hbox(10)
		var num := S.label(str(i + 1), 13, color)
		num.custom_minimum_size.x = 22
		h.add_child(num)
		var n := S.label(t.name + ("   << you are here" if here else ""), 15 if here else 14, color)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(S.label(t.realm, 13, S.MUTED if not here else S.GOLD.darkened(0.2)))
		v.add_child(h)
	return c[0]
