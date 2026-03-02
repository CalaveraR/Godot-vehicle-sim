class_name HybridTireSystem
extends Node3D

# LEGACY / DEPRECATED:
# HybridTireSystem foi substituído por TireRuntimeCoordinator.
# Mantido apenas para compatibilidade com cenas antigas.
# Não deve ser usado como pipeline principal.

var _runtime: Node = null

func _ready() -> void:
	_runtime = _resolve_runtime()
	if _runtime != null:
		# Evita qualquer risco de pipeline duplo quando coordinator existe.
		set_physics_process(false)

func _resolve_runtime() -> Node:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	return parent_node.get_node_or_null("TireRuntimeCoordinator")

func _empty_patch() -> ContactPatchData:
	return ContactPatchData.new()

func step_runtime_pipeline(delta: float = 0.0, force: bool = false) -> ContactPatchData:
	_runtime = _resolve_runtime()
	if _runtime != null and _runtime.has_method("step_runtime_pipeline"):
		return _runtime.step_runtime_pipeline(delta, force)
	return _empty_patch()

func update_contact_data() -> void:
	_runtime = _resolve_runtime()
	if _runtime != null and _runtime.has_method("update_contact_data"):
		_runtime.update_contact_data()

func calculate_unified_data() -> ContactPatchData:
	_runtime = _resolve_runtime()
	if _runtime != null and _runtime.has_method("calculate_unified_data"):
		return _runtime.calculate_unified_data()
	return _empty_patch()

func apply_to_suspension(data: ContactPatchData) -> void:
	_runtime = _resolve_runtime()
	if _runtime != null and _runtime.has_method("apply_to_suspension"):
		_runtime.apply_to_suspension(data)

func apply_to_wheel(data: ContactPatchData) -> void:
	_runtime = _resolve_runtime()
	if _runtime != null and _runtime.has_method("apply_to_wheel"):
		_runtime.apply_to_wheel(data)

func apply_to_tire_system(data: ContactPatchData, step_dt: float = 0.0) -> void:
	_runtime = _resolve_runtime()
	if _runtime != null and _runtime.has_method("apply_to_tire_system"):
		_runtime.apply_to_tire_system(data, step_dt)
