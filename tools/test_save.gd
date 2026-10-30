extends SceneTree
## Save round-trip check: play a run, save it through JSON, reload it and keep playing.
## godot --headless --path . -s tools/test_save.gd

const RunState = preload("res://scripts/run_state.gd")
const Meta = preload("res://scripts/meta.gd")


func _init() -> void:
	var meta := Meta.new()
	var a := RunState.new()
	a.setup(meta.mods(), "Save Test", 42)
	for i in 100:
		a.advance_week()
	a.buy(a.market[0].id) if not a.market.is_empty() else ""
	var json := JSON.stringify(a.to_dict(), "", true, true)
	var b := RunState.new()
	b.from_dict(JSON.parse_string(json))
	var da: Dictionary = JSON.parse_string(json)
	var db: Dictionary = JSON.parse_string(JSON.stringify(b.to_dict(), "", true, true))
	for k in da:
		if JSON.stringify(da[k], "", true, true) != JSON.stringify(db[k], "", true, true):
			print("  differs: ", k, "  ", str(da[k]).left(120), "  vs  ", str(db[k]).left(120))
	# Both copies should now play out exactly the same.
	for i in 60:
		a.advance_week()
		b.advance_week()
	print("same after 60 more weeks: ", is_equal_approx(a.money, b.money) and a.year == b.year and a.tier == b.tier, "  money ", a.money, " vs ", b.money)
	var m := Meta.new()
	m.finish_run(a, RandomNumberGenerator.new())
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	m2.claim(m2.pending.choices[0])
	print("meta reload ok: ", m2.shards > 0 and m2.pending.is_empty(), "  shards ", m2.shards)
	quit()
