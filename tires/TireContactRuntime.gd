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

func apply_to_wheel(wheel, data: Dictionary) -> void:
	if not wheel:
		return

	# Agregado chega em WORLD. Wheel.apply_forces_to_vehicle espera lateral/longitudinal em LOCAL da roda.
	var total_force_ws: Vector3 = data.get("total_force", Vector3.ZERO)
	var total_torque_ws: Vector3 = data.get("total_torque", Vector3.ZERO)
	var inv_basis := wheel.global_transform.basis.inverse()
	var total_force_local := inv_basis * total_force_ws
	var total_torque_local := inv_basis * total_torque_ws

	wheel.contact_area = data["contact_area"]
	wheel.set_ground_grip(data["weighted_grip"])
	wheel.apply_forces_to_vehicle(
		data["contact_data"],
		{
			"lateral": total_force_local.x,
			"longitudinal": total_force_local.z,
			"aligning_torque": total_torque_local.y,
			"overturning_moment": total_torque_local.x,
			"gyroscopic_torque": Vector3(0, 0, total_torque_local.z),
			"space": "local_wheel"
		}
	)

func apply_to_tire_system(tire_system, data: Dictionary, update_wear_cb: Callable) -> void:
	if not tire_system:
		return

	tire_system.total_load = data["total_force"].y
	tire_system.total_lateral_force = data["total_force"].x
	tire_system.total_longitudinal_force = data["total_force"].z
	tire_system.overturning_moment = data["total_torque"].x
	tire_system.aligning_torque = data["total_torque"].y
	tire_system.gyroscopic_torque = Vector3(0, 0, data["total_torque"].z)
	tire_system.contact_area = data["contact_area"]

	update_wear_cb.call(data)

func apply_clipping_overlaps(
	clipping_area: Area3D,
	apply_clipping_force_cb: Callable
) -> void:
	for body in clipping_area.get_overlapping_bodies():
		if body is RigidBody3D:
			apply_clipping_force_cb.call(body)
