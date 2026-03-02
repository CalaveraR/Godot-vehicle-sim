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


static func from_dict(data: Dictionary) -> TireForces:
	var out := TireForces.new()
	out.Fx = float(data.get("Fx", 0.0))
	out.Fy = float(data.get("Fy", 0.0))
	out.Fz = float(data.get("Fz", 0.0))
	out.Mz = float(data.get("Mz", 0.0))
	out.center_of_pressure_ws = data.get("center_of_pressure_ws", Vector3.ZERO)
	out.contact_confidence = float(data.get("contact_confidence", 0.0))
	out.debug = data.get("debug", {})
	return out

func to_json() -> String:
	return JSON.stringify(to_dict())
