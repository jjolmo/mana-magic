extends Node
## Loads and provides access to all JSON game databases

var ally_classes: Array = []
var enemy_classes: Array = []
var elements: Array = []
var equipments: Array = []
var heroes: Array = []
var items: Array = []
var monsters: Array = []
var shops: Array = []
var skills: Array = []
var attribute_list: Array = []
var dialogs: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	ally_classes = _load_json("res://data/databases/ally_classes.json")
	enemy_classes = _load_json("res://data/databases/enemy_classes.json")
	elements = _load_json("res://data/databases/elements.json")
	equipments = _load_json("res://data/databases/equipments.json")
	heroes = _load_json("res://data/databases/heroes.json")
	items = _load_json("res://data/databases/items.json")
	monsters = _load_json("res://data/databases/monsters.json")
	shops = _load_json("res://data/databases/shops.json")
	skills = _load_json("res://data/databases/skills.json")
	attribute_list = _load_json("res://data/databases/attributeList.json")
	reload_dialogs(GameManager.language)

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Database file not found: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	return json.data

# --- Query helpers ---

func get_hero(hero_id: int) -> Dictionary:
	for hero in heroes:
		if hero is Dictionary and int(hero.get("id", -1)) == hero_id:
			return hero
	return {}

func get_skill(skill_name: String) -> Dictionary:
	for skill in skills:
		if skill is Dictionary and skill.get("name", "") == skill_name:
			return skill
	return {}

func get_skill_by_id(skill_id: int) -> Dictionary:
	for skill in skills:
		if skill is Dictionary and skill.get("id", -1) == skill_id:
			return skill
	return {}

## GMS2: skillEnable(skillName) - sets enabled=true for a skill in the database
func enable_skill(skill_name: String) -> void:
	for skill in skills:
		if skill is Dictionary and skill.get("name", "") == skill_name:
			skill["enabled"] = true
			return

## GMS2: skillDisable(skillName) - sets enabled=false for a skill in the database
func disable_skill(skill_name: String) -> void:
	for skill in skills:
		if skill is Dictionary and skill.get("name", "") == skill_name:
			skill["enabled"] = false
			return

func get_monster(monster_id: int) -> Dictionary:
	for monster in monsters:
		if monster is Dictionary and monster.get("id", -1) == monster_id:
			return monster
	return {}

func get_monster_by_name(monster_name: String) -> Dictionary:
	for monster in monsters:
		if monster is Dictionary and str(monster.get("name", "")) == monster_name:
			return monster
	return {}

func get_item(item_id: int) -> Dictionary:
	for item in items:
		if item is Dictionary and item.get("id", -1) == item_id:
			return item
	return {}

func get_item_by_name(item_name: String) -> Dictionary:
	for item in items:
		if item is Dictionary and item.get("name", "") == item_name:
			return item
	return {}

func get_equipment(equip_id: int) -> Dictionary:
	for equip in equipments:
		if equip is Dictionary and equip.get("id", -1) == equip_id:
			return equip
	return {}

func get_equipment_by_name(equip_name: String) -> Dictionary:
	for equip in equipments:
		if equip is Dictionary and equip.get("name", "") == equip_name:
			return equip
	return {}

func get_ally_class(class_id: int) -> Dictionary:
	for cls in ally_classes:
		if cls is Dictionary and cls.get("id", -1) == class_id:
			return cls
	return {}

func get_enemy_class(class_id: int) -> Dictionary:
	for cls in enemy_classes:
		if cls is Dictionary and cls.get("id", -1) == class_id:
			return cls
	return {}

func get_enemy_class_by_name(cls_name: String) -> Dictionary:
	for cls in enemy_classes:
		if cls is Dictionary and cls.get("name", "") == cls_name:
			return cls
	# Fallback to first class if not found
	if enemy_classes.size() > 0 and enemy_classes[0] is Dictionary:
		return enemy_classes[0]
	return {}

func get_element(element_id: int) -> Dictionary:
	for elem in elements:
		if elem is Dictionary and elem.get("id", -1) == element_id:
			return elem
	return {}

func get_shop(shop_name: String) -> Dictionary:
	for shop in shops:
		if shop is Dictionary and shop.get("name", "") == shop_name:
			return shop
	return {}

func get_shop_by_seller_id(seller_id: String) -> Dictionary:
	for shop in shops:
		if shop is Dictionary and shop.get("sellerId", "") == seller_id:
			return shop
	return {}

## Reload dialogs for a specific language (GMS2: manual file swap)
func reload_dialogs(lang: String) -> void:
	if lang == "es":
		dialogs = _load_json("res://data/dialogs_es.json")
	else:
		dialogs = _load_json("res://data/dialogs.json")

func get_dialogs_for_room(room_name: String) -> Variant:
	if dialogs is Dictionary and dialogs.has(room_name):
		return dialogs[room_name]
	return null

func get_attribute_info(attr_id: int) -> Dictionary:
	for attr in attribute_list:
		if attr is Dictionary and attr.get("id", -1) == attr_id:
			return attr
	return {}
