extends Node

const SAVE_PATH: String = "user://save.cfg"
const SECTION: String = "player"
const KEY: String = "coins"
const WEAPONS_KEY: String = "owned_weapons"
const UTILITIES_KEY: String = "owned_utilities"


func save_coins(amount: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(SECTION, KEY, amount)
	config.save(SAVE_PATH)


func load_coins() -> int:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		return 0
	return config.get_value(SECTION, KEY, 0)


func add_coins(amount: int) -> void:
	var current: int = load_coins()
	save_coins(current + amount)


func get_owned_weapons() -> Array:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		return ["knife"]  # Knife is always owned by default
	var weapons: Array = config.get_value(SECTION, WEAPONS_KEY, ["knife"])
	if not weapons.has("knife"):
		weapons.append("knife")
	return weapons


func owns_weapon(weapon_id: String) -> bool:
	return get_owned_weapons().has(weapon_id)


func purchase_weapon(weapon_id: String, cost: int) -> bool:
	var coins: int = load_coins()
	if coins < cost:
		return false
	if owns_weapon(weapon_id):
		return false

	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)

	# Deduct coins
	config.set_value(SECTION, KEY, coins - cost)

	# Add weapon to owned list
	var owned: Array = get_owned_weapons()
	owned.append(weapon_id)
	config.set_value(SECTION, WEAPONS_KEY, owned)

	config.save(SAVE_PATH)
	return true


func get_utility_count(utility_id: String) -> int:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		return 0
	var utilities: Dictionary = config.get_value(SECTION, UTILITIES_KEY, {})
	return utilities.get(utility_id, 0)


func purchase_utility(utility_id: String, cost: int) -> bool:
	var coins: int = load_coins()
	if coins < cost:
		return false

	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)

	# Deduct coins
	config.set_value(SECTION, KEY, coins - cost)

	# Add utility to inventory (stackable)
	var utilities: Dictionary = config.get_value(SECTION, UTILITIES_KEY, {})
	utilities[utility_id] = utilities.get(utility_id, 0) + 1
	config.set_value(SECTION, UTILITIES_KEY, utilities)

	config.save(SAVE_PATH)
	return true


func consume_utility(utility_id: String) -> bool:
	var count: int = get_utility_count(utility_id)
	if count <= 0:
		return false

	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)

	var utilities: Dictionary = config.get_value(SECTION, UTILITIES_KEY, {})
	utilities[utility_id] = count - 1
	if utilities[utility_id] <= 0:
		utilities.erase(utility_id)
	config.set_value(SECTION, UTILITIES_KEY, utilities)

	config.save(SAVE_PATH)
	return true
