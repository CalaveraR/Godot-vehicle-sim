class_name TireContactRuntime
extends RefCounted

func update_contact_data(
	raycast_root: Node3D,
	global_origin: Vector3,
	tire_width: float,
	max_penetration_depth: float,
	stiffness: float,
	calculate_local_grip_cb: Callable,
	contact_points: Array,
	contact_normals: Array,
	contact_forces: Array,
	contact_grips: Array
) -> void:
	contact_points.clear()
	contact_normals.clear()
	contact_forces.clear()
	contact_grips.clear()

	for ray in raycast_root.get_children():
		if ray is RayCast3D and ray.is_colliding():
			var point = ray.get_collision_point()
			var normal = ray.get_collision_normal()
			var depth = max_penetration_depth - point.distance_to(global_origin)
			var force = depth * stiffness

			var lateral_pos = ray.translation.x / max(tire_width / 2.0, 0.001)
			var grip_factor = calculate_local_grip_cb.call(lateral_pos, point)

			contact_points.append(point)
			contact_normals.append(normal)
			contact_forces.append(force)
			contact_grips.append(grip_factor)

func apply_to_wheel(wheel, patch: ContactPatchData) -> TireForces:
	var out := TireForces.new()
	if not wheel:
		return out

	# Agregado chega em WORLD. Wheel.apply_forces_to_vehicle espera lateral/longitudinal em LOCAL da roda.
	var total_force_ws: Vector3 = patch.total_force
	var total_torque_ws: Vector3 = patch.total_torque
	var inv_basis := wheel.global_transform.basis.inverse()
	var total_force_local := inv_basis * total_force_ws
	var total_torque_local := inv_basis * total_torque_ws

	wheel.contact_area = patch.contact_area
	wheel.set_ground_grip(patch.weighted_grip)
	wheel.apply_forces_to_vehicle(
		patch.contact_data,
		{
			"lateral": total_force_local.x,
			"longitudinal": total_force_local.z,
			"aligning_torque": total_torque_local.y,
			"overturning_moment": total_torque_local.x,
			"gyroscopic_torque": Vector3(0, 0, total_torque_local.z),
			"space": "local_wheel"
		}
	)

	out.Fx = total_force_local.x
	out.Fy = total_force_local.z
	out.Fz = total_force_local.y
	out.Mz = total_torque_local.y
	out.center_of_pressure_ws = patch.average_position
	out.contact_confidence = patch.patch_confidence
	return out

func apply_to_tire_system(tire_system, patch: ContactPatchData, update_wear_cb: Callable) -> void:
	if not tire_system:
		return

	tire_system.total_load = patch.total_force.y
	tire_system.total_lateral_force = patch.total_force.x
	tire_system.total_longitudinal_force = patch.total_force.z
	tire_system.overturning_moment = patch.total_torque.x
	tire_system.aligning_torque = patch.total_torque.y
	tire_system.gyroscopic_torque = Vector3(0, 0, patch.total_torque.z)
	tire_system.contact_area = patch.contact_area

	update_wear_cb.call(patch)

func apply_clipping_overlaps(
	clipping_area: Area3D,
	apply_clipping_force_cb: Callable
) -> void:
	for body in clipping_area.get_overlapping_bodies():
		if body is RigidBody3D:
			apply_clipping_force_cb.call(body)
