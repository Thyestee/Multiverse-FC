extends MarginContainer
## Between runs: spend shards on Nexus upgrades and found a new club.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

var _shards: Label
var _stats: Label
var _name: LineEdit
var _start_note: Label
var _upgrades: GridContainer
var _echoes: VBoxContainer
var _history: VBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var root := S.vbox(18)
	add_child(root)

	var head := S.hbox(20)
	var titles := S.vbox(2)
	titles.add_child(S.label("MULTIVERSE FC", 40, S.GREEN))
	var sub := S.label("Take a local club to the top of the Multiverse Premier within %d years, without going bankrupt. Every run that ends, won, lost or abandoned, earns shards and an echo that make the next club stronger." % Data.MAX_YEARS, 15, S.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 700
	titles.add_child(sub)
	titles.add_child(S.label("Version %s" % ProjectSettings.get_setting("application/config/version", "dev"), 12, S.MUTED.darkened(0.3)))
	head.add_child(titles)
	head.add_child(S.spacer())
	var right := S.vbox(2)
	_shards = S.label("", 34, S.VIOLET)
	_shards.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_shards)
	_stats = S.label("", 14, S.MUTED)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_stats)
	head.add_child(right)
	root.add_child(head)

	var cols := S.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var left := S.vbox(18)
	left.custom_minimum_size.x = 360
	cols.add_child(left)
	var c := S.card("Found a new club")
	var v: VBoxContainer = c[1]
	var row := S.hbox(8)
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.max_length = 32
	_name.placeholder_text = "Club name"
	row.add_child(_name)
	row.add_child(S.button("Random", func(): _name.text = Game.random_club_name()))
	v.add_child(row)
	_start_note = S.label("", 14, S.MUTED)
	_start_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_start_note)
	var start := S.button("Kick off", _start, S.GREEN)
	start.custom_minimum_size.y = 46
	start.add_theme_font_size_override("font_size", 18)
	v.add_child(start)
	left.add_child(c[0])
	c = S.card("Echoes from past runs")
	_echoes = c[1]
	left.add_child(S.scroll(c[0]))

	var mid := S.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(S.caption("Nexus upgrades · bought with shards, kept forever"))
	_upgrades = GridContainer.new()
	_upgrades.columns = 2
	_upgrades.add_theme_constant_override("h_separation", 10)
	_upgrades.add_theme_constant_override("v_separation", 10)
	mid.add_child(S.scroll(_upgrades))
	cols.add_child(mid)

	c = S.card("Past runs")
	c[0].custom_minimum_size.x = 320
	_history = c[1]
	cols.add_child(c[0])


func _ready() -> void:
	_name.text = Game.random_club_name()


func _start() -> void:
	var n := _name.text.strip_edges()
	Game.new_run(n if n != "" else Game.random_club_name())


func refresh() -> void:
	var meta = Game.meta
	_shards.text = "%d shards" % meta.shards
	_stats.text = "%d runs · %d victories · best league reached: %s" % [meta.runs, meta.victories, Data.TIERS[meta.best_tier].name if meta.runs > 0 else "none yet"]
	var mods: Dictionary = meta.mods()
	_start_note.text = "Starts in the %s with %s." % [Data.TIERS[int(mods.start_tier)].name, Data.money(5000.0 * Data.economy(int(mods.start_tier)) * mods.start_money)]

	S.clear(_upgrades)
	for u in Data.UPGRADES:
		var lvl: int = meta.lvl(u.id)
		var maxed: bool = lvl >= u.max
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", S.box(S.PANEL, 8, 12, S.VIOLET.darkened(0.5) if lvl > 0 else S.LINE))
		var h := S.hbox(10)
		panel.add_child(h)
		var info := S.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(S.label(u.name, 16))
		var d := S.label(u.desc, 13, S.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(d)
		info.add_child(S.label("Level %d / %d" % [lvl, u.max], 13, S.VIOLET))
		h.add_child(info)
		var b := S.button("Maxed" if maxed else "%d shards" % meta.price(u.id), func(): Game.buy_upgrade(u.id), S.VIOLET)
		b.custom_minimum_size.x = 110
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not meta.can_buy(u.id)
		h.add_child(b)
		_upgrades.add_child(panel)

	while _echoes.get_child_count() > 1:
		var ch := _echoes.get_child(1)
		_echoes.remove_child(ch)
		ch.queue_free()
	if meta.echoes.is_empty():
		_echoes.add_child(S.label("None yet. You choose one at the end of every run.", 14, S.MUTED))
	for id in meta.echoes:
		var e := Data.echo(id)
		var l := S.label("%s x%d: %s" % [e.name, meta.echo_count(id), e.desc], 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_echoes.add_child(l)

	while _history.get_child_count() > 1:
		var ch := _history.get_child(1)
		_history.remove_child(ch)
		ch.queue_free()
	if meta.history.is_empty():
		_history.add_child(S.label("No runs yet.", 14, S.MUTED))
	var reasons := {"bankrupt": "bankrupt", "century": "out of time", "abandoned": "abandoned", "victory": "WON THE MULTIVERSE"}
	for i in range(meta.history.size() - 1, -1, -1):
		var h: Dictionary = meta.history[i]
		var l := S.label("%s: %s in year %d, reached the %s, %s, +%d shards" % [
			h.club, reasons.get(h.reason, h.reason), int(h.years), Data.TIERS[int(h.best_tier)].name, _trophies(int(h.trophies)), int(h.shards)],
			14, S.GOLD if h.reason == "victory" else S.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_history.add_child(l)


static func _trophies(n: int) -> String:
	return "1 trophy" if n == 1 else "%d trophies" % n
