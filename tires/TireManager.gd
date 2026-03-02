class_name TireManager
extends Node

@export var debug_print: bool = false

var contact_patch_builder: ContactPatchBuilder
var force_regime_evaluator: ForceRegimeEvaluator
var brush_model_solver: BrushModelSolver
var pressure_field_solver: PressureFieldSolver
var tire_core: TireCore

func _ready() -> void:
	contact_patch_builder = ContactPatchBuilder.new()
	force_regime_evaluator = ForceRegimeEvaluator.new()
	brush_model_solver = BrushModelSolver.new()
	pressure_field_solver = PressureFieldSolver.new()
	tire_core = TireCore.new()

func step_wheel(
	wheel_id: String,
	shader_samples: Array[TireSample],
	raycast_samples: Array[TireSample],
	dt: float,
	velocity_ws: Vector3 = Vector3.ZERO,
	previous_fz: float = 0.0
) -> TireForces:
	if tire_core == null:
		_ready()
	var forces := tire_core.step_wheel(shader_samples, raycast_samples, dt, velocity_ws, previous_fz)
	if debug_print:
		print("[TireManager] wheel=%s Fx=%.2f Fy=%.2f Fz=%.2f conf=%.2f" % [wheel_id, forces.Fx, forces.Fy, forces.Fz, forces.contact_confidence])
	return forces


# TireManager não roda pipeline em _physics_process por conta própria.
# Ele apenas coordena chamadas explícitas do Wheel/Coordinator.
