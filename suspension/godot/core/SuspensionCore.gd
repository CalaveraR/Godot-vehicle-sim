class_name SuspensionCore
extends RefCounted

static func compute_deformation_clamped(deformation: Vector3, tire_induced_deformation: Vector3) -> Dictionary:
	var raw := deformation + tire_induced_deformation
	var clamped := Vector3(
		clampf(raw.x, -0.1, 0.1),
		clampf(raw.y, -0.2, 0.0),
		clampf(raw.z, -0.1, 0.1)
	)
	return {
		"deformation": clamped,
		"flags": {
			"x_clamped": absf(raw.x - clamped.x) > 1e-6,
			"y_clamped": absf(raw.y - clamped.y) > 1e-6,
			"z_clamped": absf(raw.z - clamped.z) > 1e-6,
		}
	}

static func compute_effective_radius(
	total_load: float,
	base_vertical_stiffness: float,
	tire_radius: float,
	min_effective_radius: float,
	vertical_stiffness_mul: float = 1.0,
	dynamic_radius_mul: float = 1.0
) -> Dictionary:
	var safe_stiffness := maxf(base_vertical_stiffness, 1e-6)
	var stiffness_mul := maxf(vertical_stiffness_mul, 1e-6)
	var deflection := maxf(total_load, 0.0) / (safe_stiffness * stiffness_mul)
	var base_radius := (tire_radius - deflection) * maxf(dynamic_radius_mul, 1e-6)
	var out_radius := clampf(base_radius, min_effective_radius, tire_radius * 1.2)
	return {
		"effective_radius": out_radius,
		"deflection": deflection,
		"flags": {"radius_clamped": absf(base_radius - out_radius) > 1e-6}
	}

static func compute_relaxation_factor(default_value: float, curve_value: Variant = null) -> float:
	if curve_value == null:
		return default_value
	return float(curve_value)

static func compute_lateral_deformation(curve_value: Variant = null) -> float:
	if curve_value == null:
		return 0.0
	return float(curve_value)
