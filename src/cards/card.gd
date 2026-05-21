class_name Card
extends Resource
## Base Card resource. Specific card data lives in the game repo.

# Card categories (engine-level — themes can map onto these).
enum Category { ATTACK, SKILL, POWER, STATUS, CURSE }

@export var id: StringName
@export var display_name: String
@export var cost: int = 1
@export var description: String
# Effect composition — Cards reference Effect resources rather than embedding logic.
@export var effects: Array[Effect] = []
@export var category: Category = Category.ATTACK


func play(context: CombatContext) -> void:
	for effect in effects:
		effect.apply(context)
