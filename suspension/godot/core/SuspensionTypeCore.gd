class_name SuspensionTypeCore
extends RefCounted

static func mcperson_geometry_from_eval(bump_steer_eval: float, camber_compression_eval: float) -> Dictionary:
	return {
		"dynamic_toe_delta": bump_steer_eval,
		"dynamic_camber_delta": camber_compression_eval,
	}

static func double_wishbone_geometry(total_load: float, wishbone_angle: float) -> Dictionary:
	return {
		"dynamic_camber_delta": wishbone_angle + total_load * 0.00005,
		"dynamic_toe_delta": total_load * 0.00001,
	}

static func multilink_geometry(total_load: float, link_count: int) -> Dictionary:
	var count := max(link_count, 1)
	var load_per_link := total_load / float(count)
	var link_forces: Array = []
	link_forces.resize(count)
	for i in range(count):
		link_forces[i] = load_per_link * (1.0 + sin(float(i) * 0.5))

	var l0 := float(link_forces[0])
	var l1 := float(link_forces[1]) if count > 1 else 0.0
	var l2 := float(link_forces[2]) if count > 2 else 0.0
	return {
		"dynamic_camber_delta": l0 * 0.00001,
		"dynamic_toe_delta": (l1 - l2) * 0.00002,
	}

static func pushrod_geometry(total_load: float, rocker_ratio: float, base_vertical_stiffness: float) -> Dictionary:
	var spring_force := total_load * rocker_ratio
	var deformation_y := spring_force / maxf(base_vertical_stiffness, 1e-6)
	return {
		"deformation_y_delta": deformation_y,
		"aux_value": 0.3 + deformation_y * 0.1,
	}

static func pullrod_geometry(total_load: float, rocker_ratio: float, base_vertical_stiffness: float) -> Dictionary:
	var spring_force := total_load * rocker_ratio
	var deformation_y := spring_force / maxf(base_vertical_stiffness, 1e-6)
	return {
		"deformation_y_delta": deformation_y,
		"aux_value": -0.2 - deformation_y * 0.1,
	}

static func air_suspension_geometry(total_load: float, air_volume_liters: float, min_air_pressure: float, max_air_pressure: float) -> Dictionary:
	var new_pressure := total_load / (maxf(air_volume_liters, 1e-6) * 0.001) + min_air_pressure
	var pressure := clampf(new_pressure, min_air_pressure, max_air_pressure)
	return {
		"air_pressure": pressure,
		"base_vertical_stiffness": pressure * 300.0,
	}
