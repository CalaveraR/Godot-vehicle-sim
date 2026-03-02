class_name TireSuspensionBridge
extends RefCounted

func apply_to_suspension(
	suspension_system,
	data: Dictionary,
	tire_diameter: float,
	tire_width: float,
	rim_diameter: float
) -> void:
	if not suspension_system:
		return

	suspension_system.tire_radius = tire_diameter / 2.0
	suspension_system.tire_width = tire_width
	suspension_system.min_effective_radius = rim_diameter / 2.0

	if data["contact_points"] and data["contact_points"].size() > 0:
		suspension_system.raycast.global_transform.origin = data["average_position"]
		suspension_system.raycast.cast_to = data["average_normal"] * -1.0

	suspension_system.total_load = data["total_force"].y

	var lateral_force_ratio = abs(data["total_force"].x) / max(1.0, data["total_force"].y)
	suspension_system.lateral_deformation = lateral_force_ratio * tire_width * 0.1

	suspension_system.update_effective_radius(0.0, data["max_pressure"])
