extends Control
## Root of the game screen: the club view during a run, the hub between runs,
## and the overlays (run over, abandon confirmation, short notices).
##
## Testing flags (after `--`): --nosave  --new=Club Name  --weeks=N  --abandon  --claim  --speed=N  --tab=N
##   --screenshot=path.png  --shot_delay=S

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")
const OverviewPage = preload("res://scripts/ui/overview_page.gd")
const SquadPage = preload("res://scripts/ui/squad_page.gd")
const TransfersPage = preload("res://scripts/ui/transfers_page.gd")
const TrainingPage = preload("res://scripts/ui/training_page.gd")
const FacilitiesPage = preload("res://scripts/ui/facilities_page.gd")
const FinancesPage = preload("res://scripts/ui/finances_page.gd")
const LeaguePage = preload("res://scripts/ui/league_page.gd")
const HubScreen = preload("res://scripts/ui/hub_screen.gd")
const EndScreen = preload("res://scripts/ui/end_screen.gd")

var _run_view: VBoxContainer
var _tabs: TabContainer
var _log: RichTextLabel
var _club: Label
var _realm: Label
var _date: Label
var _season_bar: ProgressBar
var _money: Label
var _net: Label
var _fans: Label
var _speed_buttons := {}
var _hub: Control
var _end: Control
var _confirm: Control
var _toast: Label
var _toast_time := 0.0
var _last_speed := 1
var _args := {}


func _ready() -> void:
	theme = S.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = S.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_run_view()
	_hub = HubScreen.new()
	add_child(_hub)
	_end = EndScreen.new()
	add_child(_end)
	_build_confirm()
	_build_toast()
	Game.ticked.connect(_refresh)
	Game.run_started.connect(_on_run_started)
	Game.run_finished.connect(_show_screens)
	Game.log_added.connect(_add_log)
	Game.notice.connect(_show_toast)
	_replay_log()
	_show_screens()
	_handle_args()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0
	var run = Game.run
	if run == null or not _run_view.visible:
		return
	var page := _tabs.get_current_tab_control()
	if page and page.has_method("live"):
		page.live(run, Game.week_fraction())
	_season_bar.value = (run.week - 1 + Game.week_fraction()) / Data.WEEKS_PER_SEASON


func _unhandled_key_input(event: InputEvent) -> void:
	if Game.run == null or not event.is_pressed() or event.is_echo():
		return
	var key: int = event.physical_keycode
	if key == KEY_SPACE:
		_set_speed(0 if Game.speed > 0 else _last_speed)
	elif key >= KEY_1 and key <= KEY_5:
		_set_speed(Game.SPEEDS[key - KEY_1 + 1])


# --- Building ----------------------------------------------------------------

func _build_run_view() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	_run_view = S.vbox(12)
	margin.add_child(_run_view)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", S.box(S.PANEL, 10, 12))
	var bar := S.hbox(26)
	top.add_child(bar)
	var club := S.vbox(0)
	_club = S.label("", 22, S.TEXT)
	_realm = S.label("", 13, S.MUTED)
	club.add_child(_club)
	club.add_child(_realm)
	club.custom_minimum_size.x = 300
	bar.add_child(club)
	var date := S.vbox(4)
	_date = S.label("", 18)
	date.add_child(_date)
	_season_bar = S.bar(S.BLUE, 6)
	_season_bar.custom_minimum_size.x = 170
	date.add_child(_season_bar)
	bar.add_child(date)
	var money := S.vbox(0)
	_money = S.label("", 22, S.GOLD)
	_net = S.label("", 13)
	money.add_child(_money)
	money.add_child(_net)
	bar.add_child(money)
	var fans := S.vbox(0)
	_fans = S.label("", 18)
	fans.add_child(_fans)
	fans.add_child(S.label("fans", 13, S.MUTED))
	bar.add_child(fans)
	bar.add_child(S.spacer())
	var speeds := S.hbox(4)
	for s in Game.SPEEDS:
		var b := S.button("Pause" if s == 0 else "%dx" % s, _set_speed.bind(s))
		b.tooltip_text = "Space pauses and resumes; keys 1 to 5 pick a speed."
		_speed_buttons[s] = b
		speeds.add_child(b)
	speeds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(speeds)
	var quit := S.button("Abandon run", func(): _confirm.visible = true, S.RED)
	quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(quit)
	_run_view.add_child(top)

	var body := S.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_view.add_child(body)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_i): _refresh())
	for page in [OverviewPage.new(), SquadPage.new(), TransfersPage.new(), TrainingPage.new(),
			FacilitiesPage.new(), FinancesPage.new(), LeaguePage.new()]:
		_tabs.add_child(page)
	body.add_child(_tabs)

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size.x = 380
	var lv := S.vbox(8)
	log_panel.add_child(lv)
	lv.add_child(S.caption("Club news"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	_log.add_theme_constant_override("paragraph_separation", 6)
	lv.add_child(_log)
	body.add_child(log_panel)


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 520
	panel.add_theme_stylebox_override("panel", S.box(S.PANEL, 12, 24, S.RED.darkened(0.3)))
	center.add_child(panel)
	var v := S.vbox(14)
	panel.add_child(v)
	v.add_child(S.label("Abandon this run?", 24))
	var t := S.label("The club's story ends now. You still earn shards for how far you got, and pick an echo for future runs.", 15, S.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var h := S.hbox(10)
	h.add_child(S.spacer())
	h.add_child(S.button("Keep playing", func(): _confirm.visible = false))
	h.add_child(S.button("Abandon run", func():
		_confirm.visible = false
		Game.abandon(), S.RED))
	v.add_child(h)
	add_child(_confirm)


func _build_toast() -> void:
	_toast = S.label("", 16)
	_toast.add_theme_stylebox_override("normal", S.box(S.PANEL_2, 8, 12, S.GOLD.darkened(0.3)))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.position.y -= 30
	_toast.visible = false
	add_child(_toast)


# --- Updating ----------------------------------------------------------------

func _show_screens() -> void:
	var in_run: bool = Game.run != null
	_run_view.get_parent().visible = in_run
	_hub.visible = not in_run
	_end.visible = not Game.meta.pending.is_empty()
	_confirm.visible = false
	if _end.visible:
		_end.refresh()
	if in_run:
		_refresh()
	else:
		_hub.refresh()


func _on_run_started() -> void:
	_log.clear()
	_replay_log()
	_tabs.current_tab = 0
	_show_screens()


func _refresh() -> void:
	if Game.run == null:
		_hub.refresh()
		_end.visible = not Game.meta.pending.is_empty()
		if _end.visible:
			_end.refresh()
		return
	var run = Game.run
	_club.text = run.club_name
	_realm.text = "%s · %s" % [run.tier_name(), Data.TIERS[run.tier].realm]
	_date.text = "Year %d / %d · week %d" % [run.year, Data.MAX_YEARS, run.week]
	_money.text = Data.money(run.money)
	_money.add_theme_color_override("font_color", S.GOLD if run.money >= 0 else S.RED)
	# Day-to-day result per week this season, leaving out one-off buys and loans.
	var ledger: Dictionary = run.season_ledger
	var weeks: int = run.season_weeks
	if weeks == 0:
		ledger = run.last_season_ledger
		weeks = Data.WEEKS_PER_SEASON
	var net := 0.0
	for k in ledger:
		if not k in ["Loans", "Transfers", "Facilities", "Scouting"]:
			net += ledger[k] / maxf(weeks, 1)
	_net.text = ("in debt! %d weeks to bankruptcy" % (run.bankrupt_after() - run.debt_weeks)) if run.debt_weeks > 0 else "%s%s a week this season" % ["+" if net >= 0 else "", Data.money(net)]
	_net.add_theme_color_override("font_color", S.RED if run.debt_weeks > 0 or net < 0 else S.GREEN)
	_fans.text = Data.big(run.fans)
	for s in _speed_buttons:
		var b: Button = _speed_buttons[s]
		b.visible = s <= Game.meta.max_speed()
		if s == Game.speed:
			S.tint(b, S.GREEN if s > 0 else S.GOLD)
		else:
			for st in ["normal", "hover", "pressed"]:
				b.remove_theme_stylebox_override(st)
	var page := _tabs.get_current_tab_control()
	if page and page.has_method("refresh"):
		page.refresh(run)


func _set_speed(s: int) -> void:
	if s > 0:
		_last_speed = s
	Game.set_speed(s)
	_refresh()


func _replay_log() -> void:
	for e in Game.log_lines:
		_add_log(e[0], e[1], int(e[2]), int(e[3]))


func _add_log(text: String, kind: String, year: int, week: int) -> void:
	var color: Color = S.KIND_COLORS.get(kind, S.TEXT)
	var safe := text.replace("[", "[lb]")
	_log.append_text("[color=#%s]Y%d W%d[/color]  [color=#%s]%s[/color]\n" % [S.MUTED.to_html(false), year, week, color.to_html(false), safe])


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.reset_size()
	_toast.position.x = (size.x - _toast.size.x) / 2.0
	_toast.position.y = size.y - _toast.size.y - 40
	_toast_time = 2.5


# --- Testing helpers ---------------------------------------------------------

func _handle_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if _args.has("new"):
		Game.new_run(_args.new if _args.new != "" else Game.random_club_name())
	if _args.has("weeks") and Game.run:
		for i in int(_args.weeks):
			if Game.run == null:
				break
			Game.step()
	if _args.has("abandon"):
		Game.abandon()
	if _args.has("claim"):
		while not Game.meta.pending.is_empty():
			Game.claim_echo(Game.meta.pending.choices[0])
	if _args.has("speed"):
		_set_speed(int(_args.speed))
	if _args.has("tab") and Game.run:
		_tabs.current_tab = int(_args.tab)
	if _args.has("screenshot"):
		await get_tree().create_timer(float(_args.get("shot_delay", "1.5"))).timeout
		get_viewport().get_texture().get_image().save_png(_args.screenshot)
		print("Saved screenshot to ", _args.screenshot)
		get_tree().quit()
