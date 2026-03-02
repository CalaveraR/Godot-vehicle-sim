class_name TireForces
extends RefCounted

var Fx: float = 0.0
var Fy: float = 0.0
var Fz: float = 0.0
var Mz: float = 0.0

var center_of_pressure_ws: Vector3 = Vector3.ZERO
var contact_confidence: float = 0.0
var debug: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"Fx": Fx,
		"Fy": Fy,
		"Fz": Fz,
		"Mz": Mz,
		"center_of_pressure_ws": center_of_pressure_ws,
		"contact_confidence": contact_confidence,
		"debug": debug,
	}
