extends RefCounted
## Palette, theme and small widget helpers shared by every screen.

# Night-match palette: floodlit pitch green on a dark stand, gold for money,
# violet for the multiverse.
const BG := Color("0d141c")
const PANEL := Color("152029")
const PANEL_2 := Color("1b2a36")
const ROW := Color("182531")
const LINE := Color("26394a")
const TEXT := Color("e6eef5")
const MUTED := Color("8399ad")
const GREEN := Color("39d07f")
const GOLD := Color("f3c04f")
const RED := Color("ef5d5d")
const VIOLET := Color("a487ff")
const BLUE := Color("5ab0ff")

const KIND_COLORS := {
	"info": MUTED, "good": GREEN, "bad": RED, "gold": GOLD,
	"match_W": GREEN, "match_D": TEXT, "match_L": RED,
}


static func build() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Inter", "Roboto", "Noto Sans", "Arial"])
	t.default_font = font
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 10, 14))
	t.set_stylebox("panel", "Panel", box(PANEL, 10))

	t.set_stylebox("normal", "Button", box(PANEL_2, 7, 8, LINE))
	t.set_stylebox("hover", "Button", box(PANEL_2.lightened(0.08), 7, 8, GREEN.darkened(0.3)))
	t.set_stylebox("pressed", "Button", box(GREEN.darkened(0.55), 7, 8, GREEN))
	t.set_stylebox("disabled", "Button", box(PANEL_2.darkened(0.15), 7, 8, LINE.darkened(0.2)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 7, 8, GREEN.darkened(0.2)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.1))

	t.set_stylebox("tab_selected", "TabContainer", box(PANEL, 8, 10, GREEN, [0, 0, 0, 3]))
	t.set_stylebox("tab_unselected", "TabContainer", box(BG, 8, 10))
	t.set_stylebox("tab_hovered", "TabContainer", box(PANEL_2, 8, 10))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font_size("font_size", "TabContainer", 16)

	t.set_stylebox("background", "ProgressBar", box(BG, 5, 0))
	t.set_stylebox("fill", "ProgressBar", box(GREEN, 5, 0))
	t.set_stylebox("normal", "LineEdit", box(BG, 7, 8, LINE))
	t.set_stylebox("focus", "LineEdit", box(BG, 7, 8, GREEN))
	var track := box(BG, 4, 0, LINE)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(GREEN.darkened(0.2), 4, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GREEN, 4, 0))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_2, 6, 8, LINE))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(0, 0, 0, 0), 4, 0))
		t.set_stylebox("grabber", bar, box(LINE, 4, 0))
		t.set_stylebox("grabber_highlight", bar, box(LINE.lightened(0.2), 4, 0))
		t.set_stylebox("grabber_pressed", bar, box(GREEN.darkened(0.3), 4, 0))
	return t


## A rounded flat box. `border_widths` is [left, top, right, bottom].
static func box(color: Color, radius := 8, pad := 10, border := Color(0, 0, 0, 0), border_widths := [1, 1, 1, 1]) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if border.a > 0.0:
		s.border_color = border
		s.border_width_left = border_widths[0]
		s.border_width_top = border_widths[1]
		s.border_width_right = border_widths[2]
		s.border_width_bottom = border_widths[3]
	return s


static func label(text := "", size := 15, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A caption: small, muted, spaced capitals.
static func caption(text: String) -> Label:
	var l := label(text.to_upper(), 12, MUTED)
	return l


static func button(text: String, on_press: Callable, color := Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	if color.a > 0.0:
		tint(b, color)
	return b


## Gives a button a coloured style, for primary or dangerous actions.
static func tint(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", box(color.darkened(0.55), 7, 8, color.darkened(0.15)))
	b.add_theme_stylebox_override("hover", box(color.darkened(0.4), 7, 8, color))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.25), 7, 8, color))


static func card(title := "") -> Array:
	## Returns [panel, content VBox].
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	if title != "":
		v.add_child(caption(title))
	return [panel, v]


static func bar(color := GREEN, height := 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size.y = height
	p.max_value = 1.0
	p.step = 0.0
	p.add_theme_stylebox_override("fill", box(color, 5, 0))
	return p


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## A table row: cells laid out at fixed widths; a width of 0 expands.
static func row(cells: Array, widths: Array, shade := ROW) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(shade, 6, 7))
	var h := hbox(8)
	p.add_child(h)
	for i in cells.size():
		var c: Control = cells[i]
		if widths[i] == 0:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			c.custom_minimum_size.x = widths[i]
		if c is Label:
			c.clip_text = true
			c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(c)
	return p


## A scrolling page body.
static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func pos_color(pos: String) -> Color:
	return {"GK": GOLD, "DEF": BLUE, "MID": GREEN, "ATK": RED}.get(pos, MUTED)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
