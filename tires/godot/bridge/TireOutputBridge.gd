# [BRIDGE] TireOutputBridge
# Adapts core output to engine-facing force application payload.
class_name TireOutputBridge
extends RefCounted

func to_world_force(forces: TireForces, tire_basis: Basis) -> Vector3:
	# Core emits local tire components (Fx longitudinal, Fy lateral, Fz normal).
	# Mapping kept explicit to avoid hidden axis drift.
	var local_force := Vector3(forces.Fx, forces.Fz, forces.Fy)
	return tire_basis * local_force

func to_world_point(forces: TireForces, _tire_transform: Transform3D) -> Vector3:
	# Current core contract already provides center_of_pressure_ws in world space.
	return forces.center_of_pressure_ws

func build_apply_payload(forces: TireForces, tire_transform: Transform3D) -> Dictionary:
	return {
		"force_ws": to_world_force(forces, tire_transform.basis),
		"point_ws": to_world_point(forces, tire_transform),
		"confidence": forces.contact_confidence,
		"debug": forces.debug,
	}
