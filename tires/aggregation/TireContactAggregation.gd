class_name TireContactAggregation
extends RefCounted

var conventions: Dictionary = TireCoreReference.DEFAULT_CONVENTIONS.duplicate(true)

func normalize_weights(weights: Array) -> Array:
	return TireCoreReference.normalize_weights(weights, conventions)

func aggregate_patch(samples: Array) -> Dictionary:
	return TireCoreReference.aggregate_patch(samples, conventions)

func compute_effective_radius(tire_radius: float, min_effective_radius: float, vertical_load: float, stiffness: float) -> float:
	return TireCoreReference.compute_effective_radius(
		tire_radius,
		min_effective_radius,
		vertical_load,
		stiffness,
		conventions
	)

func build_unified_contact_data(
	contact_points: Array,
	contact_normals: Array,
	contact_forces: Array,
	contact_grips: Array,
	global_origin: Vector3,
	stiffness: float
) -> ContactPatchData:
	var data := ContactPatchData.new()
	data.contact_points = contact_points

	if contact_points.is_empty():
		data.contact_data = {
			"position": Vector3.ZERO,
			"normal": Vector3.UP,
			"distance": 0.0
		}
		return data

	var weight_inputs: Array = []
	weight_inputs.resize(contact_forces.size())
	for i in range(contact_forces.size()):
		weight_inputs[i] = maxf(float(contact_forces[i]), 0.0)
	var normalized_weights := normalize_weights(weight_inputs)

	for i in contact_points.size():
		var force_dir = contact_normals[i] * contact_forces[i]
		var grip_force = Vector3(
			force_dir.x * contact_grips[i],
			force_dir.y,
			force_dir.z * contact_grips[i]
		)

		data.total_force += grip_force
		data.average_position += contact_points[i]
		data.average_normal += contact_normals[i]
		data.contact_area += contact_forces[i] / max(stiffness, 1.0)
		data.max_pressure = maxf(data.max_pressure, contact_forces[i])
		data.average_grip += contact_grips[i]

	data.average_position /= contact_points.size()
	data.average_normal = data.average_normal.normalized()
	data.average_grip /= contact_points.size()

	for i in contact_points.size():
		var lever_arm = contact_points[i] - global_origin
		var force_dir = contact_normals[i] * contact_forces[i] * contact_grips[i]
		data.total_torque += lever_arm.cross(force_dir)

	if not normalized_weights.is_empty():
		data.weighted_grip = 0.0
		for i in contact_points.size():
			data.weighted_grip += contact_grips[i] * float(normalized_weights[i])

	data.contact_data = {
		"position": data.average_position,
		"normal": data.average_normal,
		"distance": (data.average_position - global_origin).length()
	}
	return data
