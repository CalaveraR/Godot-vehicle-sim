class_name TireSurfaceResponseModel
extends RefCounted

func calculate_local_grip(
	tire_system,
	lateral_pos: float,
	position: Vector3,
	radial_zones: int,
	zone_grip_factors: Dictionary
) -> float:
	var base_grip = tire_system.ground_grip_factor

	var temp_factor = 1.0
	if tire_system.temperature_friction_curve:
		var surface_temp = lerp(tire_system.surface_temperature, tire_system.core_temperature, abs(lateral_pos))
		temp_factor = tire_system.temperature_friction_curve.interpolate_baked(surface_temp)

	var wear_factor = 1.0 - (tire_system.tire_wear * abs(lateral_pos))

	var aqua_factor = 1.0
	if tire_system.water_depth > tire_system.aquaplaning_threshold:
		var radial_pos = fmod(position.angle_to(Vector3.UP), TAU) / TAU
		var zone = int(radial_pos * radial_zones)
		aqua_factor = zone_grip_factors.get(zone, 1.0)

	return base_grip * temp_factor * wear_factor * aqua_factor

func update_wear_and_temperature(tire_system, wheel_dynamics, patch: ContactPatchData, delta: float) -> void:
	var slip = wheel_dynamics.wheel_slip_ratio
	var slip_angle = wheel_dynamics.wheel_slip_angle

	var wear_rate = tire_system.base_wear_rate
	wear_rate *= 1.0 + (slip * 5.0) + (abs(slip_angle) * 3.0)
	wear_rate *= patch.max_pressure / 10000.0

	if tire_system.temperature_wear_curve:
		wear_rate *= tire_system.temperature_wear_curve.interpolate_baked(tire_system.surface_temperature)

	tire_system.tire_wear = clamp(tire_system.tire_wear + wear_rate * delta, 0.0, 1.0)

	var heat_generation = tire_system.base_heat_generation
	heat_generation *= 1.0 + (slip * 3.0) + (abs(slip_angle) * 2.0)
	heat_generation *= patch.total_force.length() / 10000.0

	var surface_heat = heat_generation * 0.7
	var core_heat = heat_generation * 0.3

	tire_system.surface_temperature += surface_heat * delta
	tire_system.core_temperature += core_heat * delta

	var cooling = tire_system.cooling_rate * (tire_system.ambient_temperature - tire_system.surface_temperature)
	tire_system.surface_temperature += cooling * delta
	tire_system.core_temperature += (cooling * 0.5) * delta

func update_aquaplaning_effects(tire_system, radial_zones: int, zone_grip_factors: Dictionary) -> void:
	if tire_system.water_depth > tire_system.aquaplaning_threshold:
		for zone in zone_grip_factors:
			var angle = float(zone) / radial_zones * TAU
			var water_risk = tire_system.aquaplaning_risk_curve.interpolate_baked(angle)
			zone_grip_factors[zone] = 1.0 - water_risk
	else:
		for zone in zone_grip_factors:
			zone_grip_factors[zone] = 1.0

func update_zone_grip_from_tire_wear(tire_system, zone_grip_factors: Dictionary) -> void:
	for zone in zone_grip_factors:
		var zone_wear = tire_system.tire_wear * (0.8 + abs(sin(zone * 0.5)) * 0.2)
		zone_grip_factors[zone] = 1.0 - zone_wear

func get_clipping_ratio(body: Node3D, clipping_area: Area3D, max_penetration_depth: float) -> float:
	var body_y = body.global_transform.origin.y
	var area_y = clipping_area.global_transform.origin.y
	var depth = clamp(area_y - body_y, 0.0, max_penetration_depth)
	return depth / max(max_penetration_depth, 0.0001)

func apply_clipping_forces(
	body: RigidBody3D,
	global_origin: Vector3,
	global_basis: Basis,
	clipping_area: Area3D,
	max_penetration_depth: float,
	stiffness: float,
	stiffness_curve,
	radial_zones: int,
	zone_grip_factors: Dictionary
) -> void:
	var ratio = get_clipping_ratio(body, clipping_area, max_penetration_depth)
	var force_magnitude = stiffness_curve.interpolate_baked(ratio) if stiffness_curve else pow(ratio, 2) * stiffness

	var local_pos = body.global_transform.origin - global_origin
	local_pos = global_basis.xform_inv(local_pos)
	var radial_pos = fmod(local_pos.angle_to(Vector3.UP), TAU) / TAU
	var zone = int(radial_pos * radial_zones)
	var grip_factor = zone_grip_factors.get(zone, 1.0)

	var force_dir = (global_origin - body.global_transform.origin).normalized()
	var force = force_dir * force_magnitude * grip_factor
	body.apply_central_force(force)
