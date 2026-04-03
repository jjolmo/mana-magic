class_name PartyManager
extends Node
## Party management - replaces createParty/getPartyLeader/addToParty from GMS2

var parties: Dictionary = {} # party_name -> Array[Actor]
var party_money: Dictionary = {} # party_name -> int
var active_party: String = "main"

func create_party(party_name: String) -> Array:
	var party: Array = []
	parties[party_name] = party
	party_money[party_name] = 0
	return party

func add_to_party(party_name: String, actor: Actor) -> void:
	if not parties.has(party_name):
		create_party(party_name)
	parties[party_name].append(actor)

func remove_from_party(party_name: String, actor: Actor) -> void:
	if parties.has(party_name):
		parties[party_name].erase(actor)

func get_party(party_name: String = "") -> Array:
	var name := party_name if party_name != "" else active_party
	return parties.get(name, [])

func get_party_leader(party_name: String = "") -> Actor:
	var party := get_party(party_name)
	if party.size() > 0:
		return party[0]
	return null

func get_money(party_name: String = "") -> int:
	var name := party_name if party_name != "" else active_party
	return party_money.get(name, 0)

func set_money(amount: int, party_name: String = "") -> void:
	var name := party_name if party_name != "" else active_party
	party_money[name] = amount

func add_money(amount: int, party_name: String = "") -> void:
	var name := party_name if party_name != "" else active_party
	party_money[name] = party_money.get(name, 0) + amount
