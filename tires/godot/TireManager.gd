class_name TireManager
extends Node

@export var debug_print: bool = false

var coordinator_by_wheel: Dictionary = {}

func register_wheel_runtime(wheel_id: String, coordinator: Node) -> void:
	coordinator_by_wheel[wheel_id] = coordinator

func unregister_wheel_runtime(wheel_id: String) -> void:
	coordinator_by_wheel.erase(wheel_id)

func step_wheel(wheel_id: String, dt: float) -> Dictionary:
	var coordinator = coordinator_by_wheel.get(wheel_id, null)
	if coordinator == null or not coordinator.has_method("step_runtime_pipeline"):
		return {"error": "missing_runtime_coordinator", "wheel_id": wheel_id}

	var patch: ContactPatchData = coordinator.step_runtime_pipeline(dt)
	if debug_print:
		print("[TireManager] wheel=%s confidence=%.3f" % [wheel_id, patch.patch_confidence if patch else 0.0])
	if patch == null:
		return {"error": "runtime_step_failed", "wheel_id": wheel_id}
	return {
		"wheel_id": wheel_id,
		"contact_confidence": patch.patch_confidence,
		"contact_area": patch.contact_area,
		"total_force": patch.total_force,
		"total_torque": patch.total_torque
	}

# TireManager não roda pipeline em _physics_process por conta própria.
# Ele apenas coordena chamadas explícitas do Wheel/Coordinator.
