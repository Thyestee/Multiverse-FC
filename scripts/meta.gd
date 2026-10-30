extends RefCounted
## Progress that survives between runs: shards, Nexus upgrades and echoes.

const Data = preload("res://scripts/data.gd")

var shards := 0
var total_shards := 0
var upgrades := {}  # id -> level
var echoes := {}  # id -> count
var runs := 0
var victories := 0
var best_tier := 0
var history: Array = []  # most recent last
var pending := {}  # reward waiting for an echo pick: {shards, choices, summary}


func lvl(id: String) -> int:
	return int(upgrades.get(id, 0))


func echo_count(id: String) -> int:
	return int(echoes.get(id, 0))


## Bonuses a new run starts with.
func mods() -> Dictionary:
	return {
		"start_money": (1.0 + 0.4 * lvl("capital")) * (1.0 + 0.15 * echo_count("vault")),
		"xp": (1.0 + 0.1 * lvl("mastery")) * (1.0 + 0.08 * echo_count("drill")),
		"income": 1.0 + 0.06 * lvl("commerce"),
		"ticket": 1.0 + 0.08 * echo_count("terraces"),
		"sponsor": 1.0 + 0.08 * echo_count("sponsors"),
		"golden": 1.0 + 0.07 * lvl("golden"),
		"fans": 1.0 + 0.25 * lvl("fans"),
		"fan_growth": 1.0 + 0.1 * echo_count("faithful"),
		"wage": maxf(0.3, (1.0 - 0.04 * lvl("thrift")) * (1.0 - 0.04 * echo_count("thrift"))),
		"scout_n": lvl("scouting"),
		"scout_q": (1.0 + 0.03 * lvl("scouting")) * (1.0 + 0.02 * echo_count("scout")),
		"iron": 2 * lvl("iron"),
		"slots": lvl("slots"),
		"start_tier": lvl("headstart"),
		"atk": 1.0 + 0.03 * echo_count("strikers"),
		"mid": 1.0 + 0.03 * echo_count("engine"),
		"def": 1.0 + 0.03 * echo_count("wall"),
		"gk": 1.0 + 0.04 * echo_count("gloves"),
		"injury": maxf(0.2, 1.0 - 0.06 * echo_count("medic")),
	}


func max_speed() -> int:
	return 16 if lvl("warp") > 0 else 8


func price(id: String) -> int:
	return Data.upgrade_price(id, lvl(id))


func can_buy(id: String) -> bool:
	return lvl(id) < Data.upgrade(id).max and shards >= price(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	shards -= price(id)
	upgrades[id] = lvl(id) + 1
	return true


static func reward_for(run) -> int:
	var s: float = 2.0 + 3.0 * pow(run.best_tier, 1.4) + run.trophies.size() + run.seasons_played / 5.0
	if run.end_reason == "victory":
		s = s * 1.25 + 60.0
	return int(round(s))


## Records the end of a run and rolls three echoes to choose from.
func finish_run(run, rng: RandomNumberGenerator) -> void:
	var reward := reward_for(run)
	runs += 1
	if run.end_reason == "victory":
		victories += 1
	best_tier = maxi(best_tier, run.best_tier)
	var summary := {
		"club": run.club_name, "reason": run.end_reason, "years": run.year, "best_tier": run.best_tier,
		"trophies": run.trophies.size(), "shards": reward,
	}
	history.append(summary)
	if history.size() > 12:
		history.pop_front()
	var ids := Data.ECHOES.map(func(e): return e.id)
	ids.shuffle()
	pending = {"shards": reward, "choices": ids.slice(0, 3), "summary": summary, "picks": 2 if run.end_reason == "victory" else 1}


## Claims the pending reward with the chosen echo.
func claim(echo_id: String) -> void:
	if pending.is_empty():
		return
	echoes[echo_id] = echo_count(echo_id) + 1
	pending.picks = int(pending.picks) - 1
	pending.choices.erase(echo_id)
	if pending.picks > 0 and not pending.choices.is_empty():
		return
	shards += int(pending.shards)
	total_shards += int(pending.shards)
	pending = {}


func to_dict() -> Dictionary:
	return {
		"shards": shards, "total_shards": total_shards, "upgrades": upgrades, "echoes": echoes, "runs": runs,
		"victories": victories, "best_tier": best_tier, "history": history, "pending": pending,
	}


func from_dict(d: Dictionary) -> void:
	shards = int(d.get("shards", 0))
	total_shards = int(d.get("total_shards", 0))
	upgrades = d.get("upgrades", {})
	echoes = d.get("echoes", {})
	runs = int(d.get("runs", 0))
	victories = int(d.get("victories", 0))
	best_tier = int(d.get("best_tier", 0))
	history = d.get("history", [])
	pending = d.get("pending", {})
