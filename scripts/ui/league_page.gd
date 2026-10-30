extends VBoxContainer
## League table, this season's fixtures, and the club's history.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")
const RunState = preload("res://scripts/run_state.gd")

const WIDTHS := [36, 0, 40, 40, 40, 40, 46, 46, 50, 54]

var _body: HBoxContainer


func _init() -> void:
	name = "League"
	_body = S.hbox(14)
	add_child(S.scroll(_body))


func refresh(run) -> void:
	S.clear(_body)
	var left := S.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	var right := S.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(left)
	_body.add_child(right)
	left.add_child(_table(run))
	left.add_child(_history(run))
	right.add_child(_fixtures(run))


func _table(run) -> Control:
	var c := S.card("%s · year %d" % [run.tier_name(), run.year])
	var v: VBoxContainer = c[1]
	v.add_theme_constant_override("separation", 4)
	var head := []
	for h in ["#", "Club", "P", "W", "D", "L", "GF", "GA", "GD", "Pts"]:
		head.append(S.caption(h))
	v.add_child(S.row(head, WIDTHS, Color(0, 0, 0, 0)))
	var order: Array = run.standings()
	for i in order.size():
		var team: int = order[i]
		var r: Dictionary = run.league.table[team]
		var us := team == 0
		var shade := S.ROW
		if i < 2 and run.tier < Data.TOP_TIER:
			shade = S.GREEN.darkened(0.78)
		elif i == 0:
			shade = S.GOLD.darkened(0.75)
		elif i >= Data.LEAGUE_SIZE - 2 and run.tier > 0:
			shade = S.RED.darkened(0.78)
		var color := S.GOLD if us else S.TEXT
		var cells := [
			S.label(str(i + 1), 14, S.MUTED), S.label(run.team_name(team), 15, color),
			S.label(str(r.p), 14), S.label(str(r.w), 14), S.label(str(r.d), 14), S.label(str(r.l), 14),
			S.label(str(r.gf), 14), S.label(str(r.ga), 14), S.label("%+d" % (r.gf - r.ga), 14),
			S.label(str(r.pts), 16, color),
		]
		v.add_child(S.row(cells, WIDTHS, shade))
	var key := "Green: promoted at the end of the season." if run.tier < Data.TOP_TIER else "Win the league to win the game."
	if run.tier > 0:
		key += " Red: relegated."
	v.add_child(S.label(key, 13, S.MUTED))
	return c[0]


func _fixtures(run) -> Control:
	var c := S.card("Your season")
	var v: VBoxContainer = c[1]
	v.add_theme_constant_override("separation", 3)
	for w in range(1, Data.LAST_MATCH_WEEK + 1):
		var text := ""
		var color := S.TEXT
		if w in Data.CUP_WEEKS:
			var round_i: int = Data.CUP_WEEKS.find(w)
			text = "Cup %s" % Data.CUP_ROUNDS[round_i]
			color = S.VIOLET
		else:
			var r: int = Data.LEAGUE_WEEKS.find(w)
			for pair in run.league.fixtures[r]:
				if pair[0] == 0:
					text = "vs %s (home)" % run.team_name(pair[1])
				elif pair[1] == 0:
					text = "at %s (away)" % run.team_name(pair[0])
		var h := S.hbox(10)
		var wl := S.label("W%d" % w, 13, S.GOLD if w == run.week else S.MUTED)
		wl.custom_minimum_size.x = 40
		h.add_child(wl)
		var t := S.label(text, 14, color if w >= run.week else S.MUTED)
		t.clip_text = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		v.add_child(h)
	var cup := "Cup: "
	if run.cup.winner == 0:
		cup += "you won it!"
	elif run.cup.out:
		cup += "knocked out."
	elif run.cup.winner >= 0:
		cup += "won by %s." % run.team_name(run.cup.winner)
	else:
		cup += "still in, next up the %s." % Data.CUP_ROUNDS[run.cup.round]
	v.add_child(S.label(cup, 14, S.VIOLET))
	return c[0]


func _history(run) -> Control:
	var c := S.card("Club history")
	var v: VBoxContainer = c[1]
	v.add_theme_constant_override("separation", 3)
	if run.history.is_empty():
		v.add_child(S.label("The first season is under way.", 14, S.MUTED))
	for i in range(run.history.size() - 1, maxi(-1, run.history.size() - 13), -1):
		var hst: Dictionary = run.history[i]
		var pos := int(hst.pos)
		var t := "Year %d · %s · %s · cup: %s" % [int(hst.year), Data.TIERS[int(hst.tier)].name, RunState.ordinal(pos), hst.cup]
		v.add_child(S.label(t, 14, S.GOLD if pos == 1 else (S.GREEN if pos == 2 else S.TEXT)))
	if not run.trophies.is_empty():
		v.add_child(S.label("Trophies: " + ", ".join(run.trophies), 13, S.GOLD))
		v.get_child(v.get_child_count() - 1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return c[0]
