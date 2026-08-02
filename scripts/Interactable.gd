class_name InteractUtil
extends RefCounted
## Convencao de interacao usada em todo o jogo (sem heranca multipla):
## qualquer no que pertenca ao grupo "interactable" e implemente
## get_interact_prompt() -> String e interact(player) -> void pode ser
## alvo do raycast de interacao do jogador. Ver Player.gd.

static func try_interact(node: Node, player: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("interactable") and node.has_method("interact"):
		node.interact(player)
		return true
	return false

static func get_prompt(node: Node) -> String:
	if node and node.has_method("get_interact_prompt"):
		return node.get_interact_prompt()
	return ""
