# [BRIDGE] TireInputBridge
# Packs engine-facing wheel/runtime state into typed core inputs.
class_name TireInputBridge
extends RefCounted

func build_wheel_state(
	wheel_transform_ws: Transform3D,
	linear_velocity_ws: Vector3,
	angular_velocity_ws: Vector3,
	tire_radius: float,
	tire_width: float,
	camber: float,
	toe: float,
	steer_input: float,
	throttle_input: float,
	brake_input: float
) -> WheelState:
	var state := WheelState.new()
	state.transform_ws = wheel_transform_ws
	state.linear_velocity_ws = linear_velocity_ws
	state.angular_velocity_ws = angular_velocity_ws
	state.tire_radius = tire_radius
	state.tire_width = tire_width
	state.camber = camber
	state.toe = toe
	state.steer_input = steer_input
	state.throttle_input = throttle_input
	state.brake_input = brake_input
	return state

func merge_samples(
	shader_samples: Array[TireSample],
	raycast_samples: Array[TireSample]
) -> Array[TireSample]:
	var merged: Array[TireSample] = []
	for s in shader_samples:
		merged.append(s)
	for s in raycast_samples:
		merged.append(s)
	return merged
