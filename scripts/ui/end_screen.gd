extends Control
## Shown when a run ends: what happened, the shards earned, and an echo to pick.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/ui/style.gd")

const TITLES := {
	"bankrupt": ["Bankrupt", "The bank closed the club's doors."],
	"century": ["A century has passed", "A hundred years went by before the club reached the top."],
	"abandoned": ["Run abandoned", "The board walked away."],
	"victory": ["Best in the multiverse!", "Your club won the Multiverse Premier."],
}

var _title: Label
var _text: Label
var _pick: Label
var _choices: HBoxContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	panel.add_theme_stylebox_override("panel", S.box(S.PANEL, 14, 28, S.VIOLET.darkened(0.3)))
	center.add_child(panel)
	var v := S.vbox(14)
	panel.add_child(v)
	_title = S.label("", 34, S.GOLD)
	v.add_child(_title)
	_text = S.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	_pick = S.label("", 18, S.VIOLET)
	v.add_child(_pick)
	_choices = S.hbox(12)
	v.add_child(_choices)


func refresh() -> void:
	var p: Dictionary = Game.meta.pending
	if p.is_empty():
		return
	var s: Dictionary = p.summary
	var t: Array = TITLES.get(s.reason, ["Run over", ""])
	_title.text = t[0]
	_title.add_theme_color_override("font_color", S.GOLD if s.reason == "victory" else (S.RED if s.reason == "bankrupt" else S.TEXT))
	_text.text = "%s\n\n%s lasted %d years, reached the %s and won %s.\nYou earn %d shards to spend in the Nexus." % [
		t[1], s.club, int(s.years), Data.TIERS[int(s.best_tier)].name, "1 trophy" if int(s.trophies) == 1 else "%d trophies" % int(s.trophies), int(p.shards)]
	var picks := int(p.picks)
	_pick.text = "Choose an echo to carry into every future run" + (" (%d picks left)" % picks if picks > 1 else "")
	S.clear(_choices)
	for id in p.choices:
		var e := Data.echo(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240, 120)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s\n\n%s\n(you have %d)" % [e.name, e.desc, Game.meta.echo_count(id)]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		S.tint(b, S.VIOLET)
		b.pressed.connect(func(): Game.claim_echo(id))
		_choices.add_child(b)
