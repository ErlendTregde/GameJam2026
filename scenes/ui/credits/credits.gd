class_name Credits
extends Control
## The credits, opened from the main menu over the island: every asset we used, who made it,
## its licence, where it is from and how we changed it. Built from the lists below into the List.

signal closed

## Applies to every model: they are drawn with the game's toon shader (scripts/stylize_import.gd).
const ALL_MODELS := "Every model is drawn with our toon shader, keeping its own textures and colours."

const MODELS := [
	{"title": "Fishing Boat", "author": "Sanket Pushkar", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/fishing-boat-6692824b088e4cc6932e015a59508a5d",
		"changes": "Scaled, given a simple collision hull and a deck you can stand on, and made drivable."},
	{"title": "Beach Umbrella Asset", "author": "beelur", "license": "CC BY-NC 4.0",
		"url": "https://sketchfab.com/3d-models/beach-umbrella-asset-fbdded313a2f4bc896eeee66af7a92e5",
		"changes": "Scaled and placed by Coco's table on island 2."},
	{"title": "Lighthouse", "author": "farooq.smurf", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/lighthouse-c4809296d8f548a690f4c01555a98c3f",
		"changes": "Scaled, the blue base removed, and given a collider."},
	{"title": "Stylized Coin", "author": "BarracudaByte", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/stylized-coin-8cd6f95c44994ed5944a42892d0ffc10",
		"changes": "Scaled into a pickup item, and drawn as a slot machine symbol."},
	{"title": "Low Poly Slot Machine", "author": "Bar0nline", "license": "CC BY-NC 4.0",
		"url": "https://sketchfab.com/3d-models/low-poly-slot-machine-d42ef425b3554abf9fc86e39a9b13389",
		"changes": "Painted reels covered by spinning reels showing our own items, and a prize tray added."},
	{"title": "Grass3D", "author": "Xillute | Dev", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/grass3d-7f20dd70872841f68e1103e0cad7b0c7",
		"changes": "Baked into one mesh and scattered as seagrass on the reefs."},
	{"title": "Ocean Set", "author": "LedyonDev", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/ocean-set-4a9bca549f8f4ccbba939c972e062631",
		"changes": "Split into separate corals, anemones, seaweed, stones and shells; scattered on the reefs and made into pickups."},
	{"title": "Water bottle [Low Poly]", "author": "Islide", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/water-bottle-low-poly-c1d1cb3a3e874b6796dff574e73c849a",
		"changes": "Baked into one mesh and made a drink with a drinking animation."},
	{"title": "Red Marine Navigation Buoy (Game Ready)", "author": "Muyaya Concept", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/red-marine-navigation-buoy-game-ready-519c88ea6d464e29988515af989a96e6",
		"changes": "Scaled, and floats on the waves above the dive spots."},
	{"title": "Polygonal Venus Statue - Low Poly", "author": "Enlil Scan", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/polygonal-venus-statue-low-poly-2616cc59a42f4cfb88879e50a2cca1a5",
		"changes": "Scaled, given a collider, and placed at the bottom of the crater."},
	{"title": "Speargun ( with Arms )", "author": "frkndgr", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/speargun-with-arms-b5654f3b36d143349eb92e513707172c",
		"changes": "Arms removed and split into parts, so the spear fires out on a line and the slide reloads."},
	{"title": "krabik [low-poly] (\"little crab\")", "author": "fizikoldun", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/low-poly-8e224d59efb14bff84c4a67788a89506",
		"changes": "Scaled; used for the crabs on the beach and the crab item."},
	{"title": "Flippers", "author": "Pixie3D", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/flippers-cf181bd6740949239f4e1660ef886013",
		"changes": "Scaled into a shop item and a HUD icon."},
	{"title": "Stylized Swimming Goggles", "author": "Funnycom", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/stylized-swimming-goggles-d46298b56f1a4b4193ee9787c6212634",
		"changes": "Scaled into a shop item and a HUD icon."},
	{"title": "Simple Table (Low Poly)", "author": "Berk Gedik", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/simple-table-low-poly-847fa35fec684e9ca57f4e3f8bdc25d0",
		"changes": "Used as Coco's selling table, with a collider and a tray for your catch."},
	{"title": "Coconut", "author": "HanSoloSnipe", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/coconut-613d472d04a7483cb81343dc9092fb7b",
		"changes": "Split into a whole and a cracked coconut; Coco is a coconut with a hand-drawn face."},
	{"title": "Low Poly Spear", "author": "Ali", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/low-poly-spear-d29af739aacf4905bf96aa48335ad96a",
		"changes": "Baked into one mesh, and also used as the speargun's spear."},
	{"title": "Coral", "author": "Lydechaser", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/coral-a34004334b744ec88fa08a6b63101ea2",
		"changes": "Scattered on the reefs; tinted red for the valuable red coral."},
	{"title": "PS1/Low Poly Great White Shark", "author": "Jellypack", "license": "CC BY-NC 4.0",
		"url": "https://sketchfab.com/3d-models/ps1low-poly-great-white-shark-54b11fd3f157410faa7ab146d7fc5da5",
		"changes": "Its swim animation drives the sharks; scaled up for the Giant Shark."},
	{"title": "Palm tree Low Poly game ready", "author": "Valykor", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/palm-tree-low-poly-game-ready-5099e0d22c94437c9903079ec20ed08e",
		"changes": "Baked into one mesh, scattered on the islands, and drops coconuts when hit."},
	{"title": "Free Animated Low Poly Cartoon Chest Kit", "author": "Overaction Game Studio", "license": "Sketchfab Standard",
		"url": "https://sketchfab.com/3d-models/free-animated-low-poly-cartoon-chest-kit-c381802c29de4d2ba63fddb9821fed95",
		"changes": "One chest shown at a time; its open animation plays when you open it."},
	{"title": "Fish01", "author": "gneissler", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/fish01-9222b79582f148778fe56d20cc0cebad",
		"changes": "Recoloured into each kind of fish, with a swimming animation and sizes by weight."},
	{"title": "low poly grass clump", "author": "sam", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/low-poly-grass-clump-5948b8498f4845e0bbfd74ced30d6c6a",
		"changes": "Baked into one mesh and scattered on the islands."},
	{"title": "Low poly Stones", "author": "rakutin", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/low-poly-stones-1d6740881ad54209bfcc3540d2f6aedd",
		"changes": "Split into separate stones and scattered on the islands."},
	{"title": "Low Poly Rock", "author": "Low Poly Model's", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/low-poly-rock-f3554d1893ba47c6a4d04664255ec021",
		"changes": "Baked into one mesh; the rock you can throw."},
	{"title": "Trident", "author": "Marek_Grz", "license": "CC BY 4.0",
		"url": "https://sketchfab.com/3d-models/trident-72e003f31d844706ae7c1ea8256a32ff",
		"changes": "Baked into one mesh; a weapon you can throw."},
]

const OTHER := [
	{"title": "Cherry Bomb One (font)", "author": "Satsuyako", "license": "SIL Open Font License 1.1",
		"url": "https://github.com/satsuyako/CherryBomb", "changes": "Used as it is for all the text in the game."},
	{"title": "Terrain3D", "author": "Cory Petkovsek & Roope Palmroos", "license": "MIT",
		"url": "https://github.com/TokisanGames/Terrain3D", "changes": "The sea floor, islands and mountains, with our own ground shader."},
	{"title": "GodotSteam", "author": "Gramps & contributors", "license": "MIT",
		"url": "https://github.com/GodotSteam/GodotSteam", "changes": "Steam lobbies, invites and voice."},
]

const LICENSE_COLORS := {"CC BY 4.0": Color(0.55, 0.85, 0.55), "CC BY-NC 4.0": Color(1.0, 0.75, 0.4)}

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_add_heading("3D models")
	var note := Label.new()
	note.text = ALL_MODELS
	note.add_theme_font_size_override("font_size", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note)
	for entry in MODELS:
		_add_entry(entry)
	_add_heading("Font and tools")
	for entry in OTHER:
		_add_entry(entry)


## Everything the credits show, as text (for tests and searching).
func all_text() -> String:
	var parts := PackedStringArray()
	for node in _list.find_children("*", "", true, false):
		if node is Label:
			parts.append(node.text)
		elif node is LinkButton:
			parts.append(node.uri)
	return "\n".join(parts)


func _add_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 30)
	_list.add_child(heading)


## One card: title, "by author" and a licence badge, the link, and how we changed it.
func _add_entry(entry: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	card.add_child(rows)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = entry.title
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var badge := Label.new()
	badge.text = entry.license
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", LICENSE_COLORS.get(entry.license, Color(0.8, 0.9, 1.0)))
	top.add_child(badge)
	rows.add_child(top)
	var by := Label.new()
	by.text = "by %s" % entry.author
	by.add_theme_font_size_override("font_size", 16)
	rows.add_child(by)
	var link := LinkButton.new()
	link.text = entry.url.trim_prefix("https://")
	link.uri = entry.url
	link.add_theme_font_size_override("font_size", 13)
	link.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	link.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.5))
	rows.add_child(link)
	var changes := Label.new()
	changes.text = entry.changes
	changes.add_theme_font_size_override("font_size", 15)
	changes.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.85))
	changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(changes)
	_list.add_child(card)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.12)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.border_color = Color(1, 1, 1, 0.35)
	style.set_border_width_all(2)
	return style


func _on_back_pressed() -> void:
	hide()
	closed.emit()
