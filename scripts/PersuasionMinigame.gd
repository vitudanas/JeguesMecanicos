class_name PersuasionMinigame
extends RefCounted
## Logica pura (sem no de cena) do minigame de labia: segurar o botao
## enche a barra, soltar (ou ter muita gambiarra quebrada) esvazia mais
## rapido. Usado por BuyerNPC.gd; a UI (PersuasionBar.tscn) so exibe o
## progresso via GameManager.persuasion_updated.

signal succeeded
signal failed

var progress: float = 0.0
var time_left: float = 8.0
var fill_rate: float = 0.45
var drain_rate: float = 0.15
var is_active: bool = false

func start(duration: float = 8.0) -> void:
	progress = 0.0
	time_left = duration
	is_active = true

func stop() -> void:
	is_active = false

func update(delta: float, holding: bool, damage_penalty: float) -> void:
	if not is_active:
		return
	time_left -= delta
	if holding:
		progress += fill_rate * delta
	else:
		progress -= (drain_rate + damage_penalty) * delta
	progress = clamp(progress, 0.0, 1.0)
	if progress >= 1.0:
		is_active = false
		succeeded.emit()
	elif time_left <= 0.0:
		is_active = false
		failed.emit()
