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
