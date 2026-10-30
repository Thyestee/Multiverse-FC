extends RefCounted
## Static tables and formulas: leagues, training, facilities, upgrades, echoes, names.

const MAX_YEARS := 100
const WEEKS_PER_SEASON := 18
const LEAGUE_SIZE := 8
const SQUAD_MAX := 18
const POSITIONS := ["GK", "DEF", "MID", "ATK"]
const FORMATION := {"GK": 1, "DEF": 4, "MID": 3, "ATK": 3}
const LEAGUE_WEEKS := [1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17]
const CUP_WEEKS := [5, 10, 15]
const CUP_ROUNDS := ["quarter-final", "semi-final", "final"]
const LAST_MATCH_WEEK := 17
const BANKRUPT_WEEKS := 6
const LOAN_TRANCHES := 5

const TIERS := [
	{"name": "Sunday League", "realm": "Your town"},
	{"name": "County League", "realm": "Your county"},
	{"name": "Regional League", "realm": "Your region"},
	{"name": "National League", "realm": "Your country"},
	{"name": "Premier Division", "realm": "Your country"},
	{"name": "Continental Elite", "realm": "Your continent"},
	{"name": "World Super League", "realm": "Earth"},
	{"name": "Parallel Earths League", "realm": "Neighbouring Earths"},
	{"name": "Rift League", "realm": "The rifts between worlds"},
	{"name": "Cosmic League", "realm": "A thousand universes"},
	{"name": "Multiverse Premier", "realm": "Every universe"},
]
const TOP_TIER := 10


## Typical player rating in a league.
static func strength(tier: float) -> float:
	return 50.0 * pow(2.0, tier)


## How much money moves around in a league, relative to the Sunday League.
static func economy(tier: float) -> float:
	return pow(1.55, tier)


static func fair_price(tier: int) -> float:
	return 5.0 * pow(1.16, tier)


static func fan_base(tier: int) -> float:
	return 700.0 * pow(1.336, tier)


static func wage_for(rating: float) -> float:
	return 1.2 * rating


static func value_for(rating: float, age: int, potential: float) -> float:
	var age_factor := 1.3 if age <= 23 else (1.0 if age <= 29 else 0.6)
	var growth := maxf(potential - rating, 0.0) / maxf(rating, 1.0)
	return 70.0 * rating * age_factor * (1.0 + growth)


# --- Training ----------------------------------------------------------------

const TRAININGS := [
	{"id": "shooting", "name": "Shooting", "line": "ATK", "desc": "+3% attack per level"},
	{"id": "passing", "name": "Passing", "line": "MID", "desc": "+3% midfield per level"},
	{"id": "defending", "name": "Defending", "line": "DEF", "desc": "+3% defence per level"},
	{"id": "keeping", "name": "Goalkeeping", "line": "GK", "desc": "+4% goalkeeping per level"},
	{"id": "fitness", "name": "Fitness", "line": "", "desc": "+0.5% whole team, 4% fewer injuries per level"},
	{"id": "tactics", "name": "Tactics", "line": "", "desc": "+1.5% whole team per level"},
]


static func training_xp_needed(level: int) -> float:
	return 30.0 * pow(1.22, level)


static func training_cost(level: int, tier: int) -> float:
	return 20.0 * pow(1.15, level) * sqrt(economy(tier))


static func intensive_cost(level: int, tier: int) -> float:
	return 8.0 * training_cost(level, tier)


# --- Facilities --------------------------------------------------------------

const FACILITIES := [
	{"id": "stadium", "name": "Stadium", "base": 2500.0, "growth": 1.7, "max": 40},
	{"id": "training_ground", "name": "Training ground", "base": 2000.0, "growth": 1.8, "max": 40},
	{"id": "coaching", "name": "Coaching staff", "base": 3000.0, "growth": 2.1, "max": 12},
	{"id": "shop", "name": "Club shop", "base": 1500.0, "growth": 1.7, "max": 40},
	{"id": "marketing", "name": "Marketing office", "base": 2000.0, "growth": 1.75, "max": 40},
	{"id": "academy", "name": "Youth academy", "base": 2500.0, "growth": 1.8, "max": 30},
	{"id": "medical", "name": "Medical centre", "base": 1500.0, "growth": 1.75, "max": 15},
]


static func facility(id: String) -> Dictionary:
	for f in FACILITIES:
		if f.id == id:
			return f
	return {}


static func upgrade_cost(id: String, level: int) -> float:
	var f := facility(id)
	return f.base * pow(f.growth, level)


static func upkeep(id: String, level: int) -> float:
	if level <= 0:
		return 0.0
	var f := facility(id)
	return 0.01 * f.base * pow(f.growth, level - 1)


static func capacity(level: int) -> float:
	return 500.0 * pow(1.5, level)


static func facility_effect(id: String, level: int) -> String:
	match id:
		"stadium": return "%s seats" % big(capacity(level))
		"training_ground": return "+%d%% training speed" % (20 * level)
		"coaching": return "%d training slots" % (2 + level / 2)
		"shop": return "+%d%% shop income" % (40 * level)
		"marketing": return "+%d%% fan base" % (10 * level)
		"academy": return "No youth intake" if level == 0 else "One youth player a season, quality %d" % level
		"medical": return "Standard injury rates" if level == 0 else "-%d%% injuries and recovery time" % (6 * level)
	return ""


# --- Meta progression --------------------------------------------------------

const UPGRADES := [
	{"id": "capital", "name": "Seed Capital", "desc": "+40% starting money", "base": 8.0, "growth": 1.6, "max": 15},
	{"id": "mastery", "name": "Training Mastery", "desc": "+10% training speed", "base": 10.0, "growth": 1.6, "max": 20},
	{"id": "commerce", "name": "Commercial Genius", "desc": "+6% all income", "base": 12.0, "growth": 1.6, "max": 20},
	{"id": "golden", "name": "Golden Generation", "desc": "+7% starting squad rating", "base": 10.0, "growth": 1.6, "max": 15},
	{"id": "fans", "name": "Loyal Fans", "desc": "+25% starting fans and fan base", "base": 8.0, "growth": 1.6, "max": 15},
	{"id": "thrift", "name": "Thrifty Contracts", "desc": "-4% wages", "base": 12.0, "growth": 1.6, "max": 10},
	{"id": "scouting", "name": "Scouting Network", "desc": "+1 player on the market, +3% their rating", "base": 12.0, "growth": 1.8, "max": 6},
	{"id": "iron", "name": "Iron Will", "desc": "+2 weeks in debt before bankruptcy", "base": 15.0, "growth": 1.8, "max": 5},
	{"id": "slots", "name": "Extra Training Slot", "desc": "+1 training slot", "base": 40.0, "growth": 3.0, "max": 3},
	{"id": "headstart", "name": "Head Start", "desc": "Start one league higher", "base": 80.0, "growth": 3.0, "max": 3},
	{"id": "warp", "name": "Time Warp", "desc": "Unlocks 16x game speed", "base": 15.0, "growth": 1.0, "max": 1},
]

const ECHOES := [
	{"id": "terraces", "name": "Echo of the Terraces", "desc": "+8% ticket income"},
	{"id": "sponsors", "name": "Echo of the Boardroom", "desc": "+8% sponsor and TV income"},
	{"id": "drill", "name": "Echo of the Drill", "desc": "+8% training speed"},
	{"id": "strikers", "name": "Echo of the Strikers", "desc": "+3% attack"},
	{"id": "engine", "name": "Echo of the Engine Room", "desc": "+3% midfield"},
	{"id": "wall", "name": "Echo of the Wall", "desc": "+3% defence"},
	{"id": "gloves", "name": "Echo of the Gloves", "desc": "+4% goalkeeping"},
	{"id": "thrift", "name": "Echo of Thrift", "desc": "-4% wages"},
	{"id": "faithful", "name": "Echo of the Faithful", "desc": "+10% fan growth"},
	{"id": "vault", "name": "Echo of the Vault", "desc": "+15% starting money"},
	{"id": "scout", "name": "Echo of the Scout", "desc": "+2% market player rating"},
	{"id": "medic", "name": "Echo of the Physio", "desc": "-6% injuries"},
]


static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


static func echo(id: String) -> Dictionary:
	for e in ECHOES:
		if e.id == id:
			return e
	return {}


static func upgrade_price(id: String, level: int) -> int:
	var u := upgrade(id)
	return int(round(u.base * pow(u.growth, level)))


# --- Names -------------------------------------------------------------------

const TOWNS := ["Ashford", "Bramley", "Cobham", "Dunmore", "Elmstead", "Fernhill", "Glenwood", "Hartfield",
	"Ivybridge", "Kingsley", "Langton", "Marlow", "Northam", "Oakham", "Penrith", "Redhill", "Stanton",
	"Thornbury", "Upton", "Westbury", "Yarrow", "Bexley", "Cresswell", "Dalby", "Hollow Creek", "Millbrook"]
const TOWN_SUFFIX := ["Rovers", "United", "Athletic", "Town", "Wanderers", "Albion", "Rangers", "Villa",
	"Swifts", "Harriers", "Corinthians", "City"]
const CITIES := ["Porto Vale", "Lindenburg", "Valmora", "Kestrel Bay", "Northport", "San Aurelio", "Novagrad",
	"Montclair", "Rivabella", "Eastmarch", "Halvard", "Kingsport", "Solvenna", "Marisco", "Belgrave",
	"Torrenza", "Ostrava Nova", "Lumiere", "Castelmar", "Brightwater"]
const CITY_SUFFIX := ["FC", "United", "Sporting", "Dynamo", "Real", "Olympic", "Athletic", "Inter", "Racing", "City"]
const COSMIC := ["Mirror London", "Other Paris", "Echo Rio", "Nebula", "Quasar", "Paradox", "Chrono", "Void",
	"Helix", "Prism", "Aurora", "Obsidian", "Zenith", "Tachyon", "Singularity", "Event Horizon", "Andromeda",
	"Vortex", "Eclipse", "Infinity"]
const COSMIC_SUFFIX := ["Titans", "Stars", "Dynamo", "Wanderers", "Galaxy", "United", "Eternals", "Comets",
	"Phantoms", "Ascendants"]

const FIRST_NAMES := ["Alex", "Ben", "Carlos", "Dani", "Eli", "Felix", "Gabe", "Hugo", "Ivan", "Jonas", "Kai",
	"Leo", "Marco", "Nico", "Omar", "Pablo", "Rafa", "Sami", "Theo", "Umar", "Victor", "Wes", "Yuri", "Zeke",
	"Luca", "Mateo", "Jamal", "Kenji", "Arno", "Bastien", "Ciro", "Dario", "Emre", "Tomas", "Joao", "Malik"]
const LAST_NAMES := ["Adams", "Baker", "Costa", "Duarte", "Evans", "Fischer", "Garcia", "Hughes", "Ivanov",
	"Jensen", "Kowalski", "Lopez", "Moreau", "Novak", "Okafor", "Petrov", "Quinn", "Rossi", "Silva", "Tanaka",
	"Ueda", "Varga", "Walsh", "Xavier", "Young", "Zimmer", "Bauer", "Conti", "Diallo", "Mensah", "Lindqvist"]


static func club_name(tier: int, rng: RandomNumberGenerator) -> String:
	if tier <= 2:
		return "%s %s" % [pick(TOWNS, rng), pick(TOWN_SUFFIX, rng)]
	if tier <= 6:
		return "%s %s" % [pick(CITIES, rng), pick(CITY_SUFFIX, rng)]
	return "%s %s" % [pick(COSMIC, rng), pick(COSMIC_SUFFIX, rng)]


static func player_name(tier: int, rng: RandomNumberGenerator) -> String:
	var n := "%s %s" % [pick(FIRST_NAMES, rng), pick(LAST_NAMES, rng)]
	if tier >= 7:
		n += " (Earth-%d)" % rng.randi_range(2, 999)
	return n


static func pick(list: Array, rng: RandomNumberGenerator):
	return list[rng.randi() % list.size()]


# --- Formatting --------------------------------------------------------------

const SUFFIXES := ["", "k", "M", "B", "T", "Qa", "Qi", "Sx"]


## 1234 -> "1.2k", 5600000 -> "5.6M".
static func big(value: float) -> String:
	var v := absf(value)
	var sign := "-" if value < 0 else ""
	if v < 1000.0:
		return sign + str(int(round(v)))
	var i := 0
	while v >= 1000.0 and i < SUFFIXES.size() - 1:
		v /= 1000.0
		i += 1
	var digits := "%.2f" if v < 10.0 else ("%.1f" if v < 100.0 else "%.0f")
	return sign + (digits % v) + SUFFIXES[i]


static func money(value: float) -> String:
	if value < 0:
		return "-$" + big(-value)
	return "$" + big(value)
