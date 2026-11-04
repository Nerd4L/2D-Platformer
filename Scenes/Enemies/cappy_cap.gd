extends Enemy
class_name CappyCap

func _enemy_ready() -> void:
	inhale_score = 200
	defeat_score = 200
	anim_sprite.play("cappy_cap_only")

func _physics_process(delta: float) -> void:
	if state == State.BEING_INHALED:
		process_inhale(delta)
