# res://core/input/raycast/RaycastSampleReader.gd
class_name RaycastSampleReader
extends Node3D

@export var ray_count: int = 16
@export var tire_width: float = 0.25
@export var ray_origin_height: float = 0.5
@export var ray_length: float = 0.35
@export var collision_mask: int = 1
@export var base_confidence: float = 0.8
@export var exclude_nodes: Array[Node] = []

func read_samples(
	direct_space_state: PhysicsDirectSpaceState3D,
	now_s: float = -1.0
) -> Array[TireSample]:
	var samples: Array[TireSample] = []
	if now_s < 0.0:
		now_s = Time.get_unix_time_from_system()

	var wheel_xform: Transform3D = global_transform
	var inv := wheel_xform.affine_inverse()

	for i in range(ray_count):
		var lat := float(i) / float(max(1, ray_count - 1)) - 0.5
		var origin_local := Vector3(lat * tire_width, ray_origin_height, 0.0)
		var origin_ws := wheel_xform * origin_local
		var target_ws := origin_ws + Vector3.DOWN * ray_length

		var query := PhysicsRayQueryParameters3D.create(origin_ws, target_ws)
		query.exclude = exclude_nodes
		query.collision_mask = collision_mask

		var result := direct_space_state.intersect_ray(query)
		if result:
			var hit_pos_ws: Vector3 = result.position
			var hit_normal_ws: Vector3 = result.normal.normalized()
			var hit_distance := origin_ws.distance_to(hit_pos_ws)
			var penetration := maxf(0.0, ray_length - hit_distance)

			var hit_pos_local := inv * hit_pos_ws
			var hit_normal_local := (inv.basis * hit_normal_ws).normalized()

			var sample := TireSample.from_raycast(
				hit_pos_ws,
				hit_normal_ws,
				penetration,
				base_confidence,
				Vector2.ZERO,
				0.0,
				i,
				0,
				hit_pos_local,
				hit_normal_local
			)
			sample.timestamp_s = now_s
			samples.append(sample)

	return samples
