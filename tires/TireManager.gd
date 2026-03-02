class_name TireManager
extends Node

@export var debug_print: bool = false

var coordinator_by_wheel: Dictionary = {}

func register_wheel_runtime(wheel_id: String, coordinator: Node) -> void:
	coordinator_by_wheel[wheel_id] = coordinator

func unregister_wheel_runtime(wheel_id: String) -> void:
	coordinator_by_wheel.erase(wheel_id)

func step_wheel(wheel_id: String, dt: float, force_step: bool = true) -> Dictionary:
	var coordinator = coordinator_by_wheel.get(wheel_id, null)
	if coordinator == null or not coordinator.has_method("step_runtime_pipeline"):
		return {"error": "missing_runtime_coordinator", "wheel_id": wheel_id}

	var out: Dictionary = coordinator.step_runtime_pipeline(dt, force_step)
	if debug_print:
		print("[TireManager] wheel=%s stepped=%s" % [wheel_id, not out.get("skipped", false)])
	return out

# TireManager não roda pipeline em _physics_process por conta própria.
# Ele apenas coordena chamadas explícitas do Wheel/Coordinator.
