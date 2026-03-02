class_name TireContactAggregation
extends RefCounted

func build_unified_contact_data(
	contact_points: Array,
	contact_normals: Array,
	contact_forces: Array,
	contact_grips: Array,
	global_origin: Vector3,
	stiffness: float
) -> Dictionary:
	var data = {
		"total_force": Vector3.ZERO,
		"total_torque": Vector3.ZERO,
		"units": {"force": "N", "torque": "N.m"},
		"space": {"total_force": "world", "total_torque": "world"},
		"average_position": Vector3.ZERO,
		"average_normal": Vector3.UP,
		"contact_area": 0.0,
		"max_pressure": 0.0,
		"average_grip": 1.0,
		"weighted_grip": 1.0,
		"contact_points": contact_points,
		"contact_data": {}
	}

	if contact_points.is_empty():
		return data

	for i in contact_points.size():
		var force_dir = contact_normals[i] * contact_forces[i]
		var grip_force = Vector3(
			force_dir.x * contact_grips[i],
			force_dir.y,
			force_dir.z * contact_grips[i]
		)

		data["total_force"] += grip_force
		data["average_position"] += contact_points[i]
		data["average_normal"] += contact_normals[i]
		data["contact_area"] += contact_forces[i] / max(stiffness, 1.0)
		data["max_pressure"] = max(data["max_pressure"], contact_forces[i])
		data["average_grip"] += contact_grips[i]

	data["average_position"] /= contact_points.size()
	data["average_normal"] = data["average_normal"].normalized()
	data["average_grip"] /= contact_points.size()

	for i in contact_points.size():
		var lever_arm = contact_points[i] - global_origin
		var force_dir = contact_normals[i] * contact_forces[i] * contact_grips[i]
		data["total_torque"] += lever_arm.cross(force_dir)

	var total_force_magnitude = data["total_force"].length()
	if total_force_magnitude > 0.0:
		data["weighted_grip"] = 0.0
		for i in contact_points.size():
			var force_ratio = contact_forces[i] / total_force_magnitude
			data["weighted_grip"] += contact_grips[i] * force_ratio

	data["contact_data"] = {
		"position": data["average_position"],
		"normal": data["average_normal"],
		"distance": (data["average_position"] - global_origin).length()
	}

	return data
