extends Node
## Autoload: owns the meta progress and the current run, advances time and saves.

const Data = preload("res://scripts/data.gd")
const RunState = preload("res://scripts/run_state.gd")
const Meta = preload("res://scripts/meta.gd")

const WEEK_SECONDS := 3.0
const META_PATH := "user://meta.json"
const RUN_PATH := "user://run.json"
const SPEEDS := [0, 1, 2, 4, 8, 16]

signal ticked  # a week went by, or the player did something
signal run_started
signal run_finished
signal log_added(text: String, kind: String, year: int, week: int)
signal notice(text: String)  # a short message for the player, like "Not enough money."

var meta := Meta.new()
var run: RunState
var speed := 1
var log_lines: Array = []  # recent events, kept for the log panel
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
var _saving := true  # off with --nosave, so test runs leave the real save alone


func _ready() -> void:
	_rng.randomize()
	_saving = not OS.get_cmdline_user_args().has("--nosave")
	if _saving:
		_load()
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()


func _process(delta: float) -> void:
	if run == null or run.ended or speed == 0:
		return
	_acc += delta * speed
	while _acc >= WEEK_SECONDS and not run.ended:
		_acc -= WEEK_SECONDS
		step()


## How far through the current week we are, for smooth progress bars.
func week_fraction() -> float:
	return clampf(_acc / WEEK_SECONDS, 0.0, 1.0) if run and not run.ended and speed > 0 else 0.0


func step() -> void:
	run.advance_week()
	_drain_events()
	if run.ended:
		_finish()
		return
	if run.week % 4 == 1:
		save()
	ticked.emit()


func set_speed(value: int) -> void:
	speed = mini(value, meta.max_speed())


func new_run(club_name: String) -> void:
	run = RunState.new()
	log_lines.clear()
	_acc = 0.0
	run.setup(meta.mods(), club_name, _rng.randi())
	_drain_events()
	speed = 1
	save()
	run_started.emit()
	ticked.emit()


func random_club_name() -> String:
	return "%s %s" % [Data.pick(Data.TOWNS, _rng), Data.pick(Data.TOWN_SUFFIX, _rng)]


func abandon() -> void:
	if run == null or run.ended:
		return
	run.abandon()
	_drain_events()
	_finish()


func _finish() -> void:
	speed = 0
	meta.finish_run(run, _rng)
	run = null
	save()
	run_finished.emit()


## Runs a player action on the current run and reports why it failed, if it did.
func act(result: String) -> bool:
	_drain_events()
	if result != "":
		notice.emit(result)
	ticked.emit()
	return result == ""


func _drain_events() -> void:
	for e in run.events:
		log_lines.append(e)
		log_added.emit(e[0], e[1], e[2], e[3])
	run.events.clear()
	if log_lines.size() > 300:
		log_lines = log_lines.slice(log_lines.size() - 300)


func claim_echo(id: String) -> void:
	meta.claim(id)
	save()
	ticked.emit()


func buy_upgrade(id: String) -> void:
	if meta.buy(id):
		save()
	ticked.emit()


# --- Saving ------------------------------------------------------------------

func save() -> void:
	if not _saving:
		return
	_write(META_PATH, meta.to_dict())
	if run != null and not run.ended:
		var d := run.to_dict()
		d["log"] = log_lines.slice(maxi(0, log_lines.size() - 80))
		_write(RUN_PATH, d)
	elif FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


func _load() -> void:
	var m = _read(META_PATH)
	if m is Dictionary:
		meta.from_dict(m)
	var r = _read(RUN_PATH)
	if r is Dictionary and not r.get("ended", false):
		run = RunState.new()
		run.from_dict(r)
		log_lines = r.get("log", [])
		speed = 0


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "", true, true))


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
