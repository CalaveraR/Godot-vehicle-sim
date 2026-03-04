class_name AxleCore
extends RefCounted

static func compute_solid_axle(load_left: float, load_right: float, axle_stiffness: float) -> Dictionary:
	var avg_load := (load_left + load_right) * 0.5
	var k := maxf(axle_stiffness, 1e-6)
	return {
		"balanced_load": avg_load,
		"deformation_y_left": (load_left - avg_load) / k,
		"deformation_y_right": (load_right - avg_load) / k,
	}
