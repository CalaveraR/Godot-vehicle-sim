class_name TireProfileMeshBuilder
extends RefCounted

# Gera malha de perfil do pneu por revolução radial.
# A curva 2D representa o perfil horizontal editável por modders.
func build_profile_mesh(
	curve_profile: Curve2D,
	tire_width: float,
	tire_diameter: float,
	rim_diameter: float,
	vertical_zones: int,
	radial_zones: int
) -> ArrayMesh:
	var safe_vertical := max(vertical_zones, 2)
	var safe_radial := max(radial_zones, 3)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var profile_points: Array[Vector3] = []
	var use_curve_profile = curve_profile and curve_profile.get_point_count() >= 2
	var baked_len: float = curve_profile.get_baked_length() if use_curve_profile else 0.0

	for i in range(safe_vertical):
		var t = float(i) / float(safe_vertical - 1)
		if use_curve_profile and baked_len > 0.0:
			var curve_pt: Vector2 = curve_profile.sample_baked(t * baked_len)
			profile_points.append(Vector3(curve_pt.x, curve_pt.y, 0.0))
		else:
			# fallback procedural para manter retrocompatibilidade
			var x = lerp(-tire_width / 2.0, tire_width / 2.0, t)
			var y = sin(t * PI) * (tire_diameter - rim_diameter) / 2.0
			profile_points.append(Vector3(x, y, 0.0))

	var angle_step = TAU / float(safe_radial)
	for radial_idx in range(safe_radial):
		var angle = radial_idx * angle_step
		var next_angle = (radial_idx + 1) * angle_step

		for vert_idx in range(safe_vertical - 1):
			var p1 = profile_points[vert_idx].rotated(Vector3.UP, angle)
			var p2 = profile_points[vert_idx + 1].rotated(Vector3.UP, angle)
			var p3 = profile_points[vert_idx + 1].rotated(Vector3.UP, next_angle)
			var p4 = profile_points[vert_idx].rotated(Vector3.UP, next_angle)

			surface_tool.add_vertex(p1)
			surface_tool.add_vertex(p2)
			surface_tool.add_vertex(p3)

			surface_tool.add_vertex(p1)
			surface_tool.add_vertex(p3)
			surface_tool.add_vertex(p4)

	return surface_tool.commit()
