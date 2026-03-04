class_name SuspensionResponseCore
extends RefCounted

static func calculate_dynamic_response(lateral_g: float, load_transfer_curve_eval: float, bump_steer_curve_eval: float, roll_center_curve_eval: float) -> Dictionary:
	return {
		"load_transfer": load_transfer_curve_eval * signf(lateral_g),
		"dynamic_bump_steer": bump_steer_curve_eval,
		"roll_center_height": roll_center_curve_eval,
	}
