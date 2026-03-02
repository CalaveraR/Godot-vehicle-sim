class_name WheelState
extends RefCounted

# Snapshot de estado da roda por tick (somente dados).
# Sem lógica de força para manter separação de responsabilidades.

var transform_ws: Transform3D = Transform3D.IDENTITY
var linear_velocity_ws: Vector3 = Vector3.ZERO
var angular_velocity_ws: Vector3 = Vector3.ZERO

var tire_radius: float = 0.0
var tire_width: float = 0.0
var camber: float = 0.0
var toe: float = 0.0

var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

func to_dict() -> Dictionary:
	return {
		"transform_ws": transform_ws,
		"linear_velocity_ws": linear_velocity_ws,
		"angular_velocity_ws": angular_velocity_ws,
		"tire_radius": tire_radius,
		"tire_width": tire_width,
		"camber": camber,
		"toe": toe,
		"steer_input": steer_input,
		"throttle_input": throttle_input,
		"brake_input": brake_input,
	}


func to_json() -> String:
	return JSON.stringify(to_dict())

static func from_dict(data: Dictionary) -> WheelState:
	var out := WheelState.new()
	out.linear_velocity_ws = data.get("linear_velocity_ws", Vector3.ZERO)
	out.angular_velocity_ws = data.get("angular_velocity_ws", Vector3.ZERO)
	out.tire_radius = float(data.get("tire_radius", 0.0))
	out.tire_width = float(data.get("tire_width", 0.0))
	out.camber = float(data.get("camber", 0.0))
	out.toe = float(data.get("toe", 0.0))
	out.steer_input = float(data.get("steer_input", 0.0))
	out.throttle_input = float(data.get("throttle_input", 0.0))
	out.brake_input = float(data.get("brake_input", 0.0))
	return out

static func validate_optional(state: WheelState) -> bool:
	if state == null:
		return false
	return state.tire_radius >= 0.0 and state.tire_width >= 0.0
