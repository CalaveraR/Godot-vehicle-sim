class_name TireProfileMeshBuilder
extends RefCounted

## Responsabilidade única:
## gerar a malha de perfil do pneu a partir de uma Curve2D (modder-friendly)
## com fallback procedural quando necessário.

func build_profile_mesh(
    curve_2d: Curve2D,
    tire_width: float,
    tire_diameter: float,
    rim_diameter: float,
    vertical_zones: int,
    radial_zones: int
) -> ArrayMesh:
    var surface_tool = SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

    var v_zones := max(vertical_zones, 2)
    var r_zones := max(radial_zones, 3)

    var profile_points: Array[Vector3] = []
    var use_curve_profile := curve_2d and curve_2d.get_point_count() >= 2
    var baked_len := curve_2d.get_baked_length() if use_curve_profile else 0.0

    for i in range(v_zones):
        var t = float(i) / float(v_zones - 1)
        if use_curve_profile and baked_len > 0.0:
            var curve_pt: Vector2 = curve_2d.sample_baked(t * baked_len)
            profile_points.append(Vector3(curve_pt.x, curve_pt.y, 0.0))
        else:
            var x = lerp(-tire_width / 2.0, tire_width / 2.0, t)
            var y = sin(t * PI) * (tire_diameter - rim_diameter) / 2.0
            profile_points.append(Vector3(x, y, 0.0))

    var angle_step = TAU / float(r_zones)
    for radial_idx in range(r_zones):
        var angle = float(radial_idx) * angle_step
        var next_angle = float(radial_idx + 1) * angle_step

        for vert_idx in range(v_zones - 1):
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
