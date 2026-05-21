extends Node
## CardRegistry — stub autoload.
##
## Eventually owns the catalogue of registered Card resources keyed by id and
## handles theme/pack loading. Kept untyped + empty for now so the project
## boots before Card's effect/context dependencies exist; flesh out once the
## card system grows past the base Card resource.

var _cards: Dictionary = {}


func register(card: Resource) -> void:
	_cards[card.id] = card


func get_card(id: StringName) -> Resource:
	return _cards.get(id)


func all_ids() -> Array:
	return _cards.keys()
