extends RefCounted
## The main menu has a Credits button: it opens the credits over the island (the menu hides), which
## list every asset's title, author, licence, link and how we changed it; Back returns to the menu.

var tree: SceneTree

const LINKS := [
	"fishing-boat-6692824b088e4cc6932e015a59508a5d", "beach-umbrella-asset-fbdded313a2f4bc896eeee66af7a92e5",
	"lighthouse-c4809296d8f548a690f4c01555a98c3f", "stylized-coin-8cd6f95c44994ed5944a42892d0ffc10",
	"low-poly-slot-machine-d42ef425b3554abf9fc86e39a9b13389", "grass3d-7f20dd70872841f68e1103e0cad7b0c7",
	"ocean-set-4a9bca549f8f4ccbba939c972e062631", "water-bottle-low-poly-c1d1cb3a3e874b6796dff574e73c849a",
	"red-marine-navigation-buoy-game-ready-519c88ea6d464e29988515af989a96e6",
	"polygonal-venus-statue-low-poly-2616cc59a42f4cfb88879e50a2cca1a5", "speargun-with-arms-b5654f3b36d143349eb92e513707172c",
	"low-poly-8e224d59efb14bff84c4a67788a89506", "flippers-cf181bd6740949239f4e1660ef886013",
	"stylized-swimming-goggles-d46298b56f1a4b4193ee9787c6212634", "simple-table-low-poly-847fa35fec684e9ca57f4e3f8bdc25d0",
	"coconut-613d472d04a7483cb81343dc9092fb7b", "low-poly-spear-d29af739aacf4905bf96aa48335ad96a",
	"coral-a34004334b744ec88fa08a6b63101ea2", "ps1low-poly-great-white-shark-54b11fd3f157410faa7ab146d7fc5da5",
	"palm-tree-low-poly-game-ready-5099e0d22c94437c9903079ec20ed08e",
]


func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	tree.change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
	for k in 30:
		await tree.process_frame
	var menu: Node = tree.current_scene
	var button: Button = menu.find_child("CreditsButton", true, false)
	assert(button and button.text == "Credits", "the menu has a Credits button")
	button.pressed.emit()
	await tree.process_frame
	var credits: Credits = menu.find_child("Credits", true, false)
	assert(credits and credits.visible and not menu.find_child("Menu", true, false).visible, "credits open, the menu hides")
	var shown := credits.all_text()
	for link: String in LINKS:
		assert(shown.contains(link), "credits link %s" % link)
	for entry in Credits.MODELS:
		assert(not entry.author.is_empty() and not entry.license.is_empty() and not entry.changes.is_empty(), "%s: author, licence and changes" % entry.title)
	assert(shown.contains("Cherry Bomb One"), "the font is credited")
	credits.find_child("BackButton", true, false).pressed.emit()
	await tree.process_frame
	assert(not credits.visible and menu.find_child("Menu", true, false).visible, "Back returns to the menu")
	print("PASS test_credits")
	tree.quit()
