extends Node3D
class_name HybridTireSystem

export var tire_width: float = 0.305
export var tire_diameter: float = 0.720
export var rim_diameter: float = 0.4572
export var max_suspension_travel: float = 0.25
export var raycast_count: int = 7
export var vertical_zones: int = 8
export var radial_zones: int = 8
export var stiffness: float = 50000.0
export(Curve) var stiffness_curve

var tire_system: TireSystem
var wheel: Wheel
var suspension_system: SuspensionSystem
var wheel_dynamics: WheelDynamics

onready var raycast_root = $Raycasts
onready var clipping_area = $Area3D
onready var curve_2d = preload("res://default_tire_profile.tres") as Curve2D

var max_penetration_depth: float = 0.05
var contact_points = []
var contact_normals = []
var contact_forces = []
var contact_grips = []
var zone_grip_factors = {}

func _ready():
    tire_system = get_parent().get_node("TireSystem")
    wheel = get_parent()
    suspension_system = get_parent().get_node("SuspensionSystem")
    wheel_dynamics = get_parent().get_node("WheelDynamics")
    
    _generate_raycast_array()
    _generate_clipping_mesh()
    _initialize_grip_zones()

func _initialize_grip_zones():
    for i in radial_zones:
        zone_grip_factors[i] = 1.0

func _generate_raycast_array():
    if raycast_root:
        for child in raycast_root.get_children():
            child.queue_free()
    else:
        raycast_root = Node3D.new()
        raycast_root.name = "Raycasts"
        add_child(raycast_root)
    
    var spacing = tire_width / float(raycast_count - 1)
    var start_x = -tire_width / 2.0

    for i in raycast_count:
        var ray = RayCast3D.new()
        ray.name = "Raycast_%d" % i
        ray.cast_to = Vector3(0, -(max_suspension_travel + tire_diameter / 2.0), 0)
        ray.enabled = true
        ray.translation = Vector3(start_x + i * spacing, 0, 0)
        ray.rotation_degrees.x = -90.0
        ray.collision_mask = 1
        raycast_root.add_child(ray)

func _generate_clipping_mesh():
    if not clipping_area:
        clipping_area = Area3D.new()
        clipping_area.name = "Area3D"
        add_child(clipping_area)
    
    if clipping_area.get_node("ClippingMesh"):
        clipping_area.get_node("ClippingMesh").queue_free()
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "ClippingMesh"
    clipping_area.add_child(mesh_instance)
    
    var mesh = _create_tire_profile_mesh()
    mesh_instance.mesh = mesh
    clipping_area.translation.y = -max_suspension_travel / 2.0

func _create_tire_profile_mesh() -> ArrayMesh:
    var surface_tool = SurfaceTool.new()
    surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    var profile_points = []
    for i in vertical_zones:
        var t = float(i) / (vertical_zones - 1)
        var x = lerp(-tire_width / 2.0, tire_width / 2.0, t)
        var y = sin(t * PI) * (tire_diameter - rim_diameter) / 2.0
        profile_points.append(Vector3(x, y, 0))
    
    var angle_step = TAU / radial_zones
    for radial_idx in radial_zones:
        var angle = radial_idx * angle_step
        var next_angle = (radial_idx + 1) * angle_step
        
        for vert_idx in range(vertical_zones - 1):
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
    
    var array_mesh = surface_tool.commit()
    return array_mesh

func update_contact_data():
    contact_points.clear()
    contact_normals.clear()
    contact_forces.clear()
    contact_grips.clear()
    
    for ray in raycast_root.get_children():
        if ray is RayCast3D and ray.is_colliding():
            var point = ray.get_collision_point()
            var normal = ray.get_collision_normal()
            var depth = max_penetration_depth - point.distance_to(ray.global_transform.origin)
            var force = depth * stiffness
            
            var lateral_pos = ray.translation.x / (tire_width / 2.0)
            var grip_factor = calculate_local_grip(lateral_pos, point)
            
            contact_points.append(point)
            contact_normals.append(normal)
            contact_forces.append(force)
            contact_grips.append(grip_factor)

func calculate_local_grip(lateral_pos: float, position: Vector3) -> float:
    var base_grip = tire_system.ground_grip_factor
    
    var temp_factor = 1.0
    if tire_system.temperature_friction_curve:
        var surface_temp = lerp(tire_system.surface_temperature, tire_system.core_temperature, abs(lateral_pos))
        temp_factor = tire_system.temperature_friction_curve.interpolate_baked(surface_temp)
    
    var wear_factor = 1.0 - (tire_system.tire_wear * abs(lateral_pos))
    
    var aqua_factor = 1.0
    if tire_system.water_depth > tire_system.aquaplaning_threshold:
        var radial_pos = fmod(position.angle_to(Vector3.UP), TAU) / TAU
        var zone = int(radial_pos * radial_zones)
        aqua_factor = zone_grip_factors.get(zone, 1.0)
    
    return base_grip * temp_factor * wear_factor * aqua_factor

func calculate_unified_data() -> Dictionary:
    var data = {
        "total_force": Vector3.ZERO,
        "total_torque": Vector3.ZERO,
        "average_position": Vector3.ZERO,
        "average_normal": Vector3.UP,
        "contact_area": 0.0,
        "max_pressure": 0.0,
        "average_grip": 1.0,
        "weighted_grip": 1.0,
        "contact_data": {}
    }
    
    if contact_points.size() == 0:
        return data
    
    for i in contact_points.size():
        var force_dir = contact_normals[i] * contact_forces[i]
        var grip_force = Vector3(
            force_dir.x * contact_grips[i],
            force_dir.y,
            force_dir.z * contact_grips[i]
        )
        
        data["total_force"] += grip_force
        data["average_position"] += contact_points[i]
        data["average_normal"] += contact_normals[i]
        data["contact_area"] += contact_forces[i] / stiffness
        data["max_pressure"] = max(data["max_pressure"], contact_forces[i])
        data["average_grip"] += contact_grips[i]
    
    data["average_position"] /= contact_points.size()
    data["average_normal"] = data["average_normal"].normalized()
    data["average_grip"] /= contact_points.size()
    
    var center = global_transform.origin
    for i in contact_points.size():
        var lever_arm = contact_points[i] - center
        var force_dir = contact_normals[i] * contact_forces[i] * contact_grips[i]
        data["total_torque"] += lever_arm.cross(force_dir)
    
    var total_force_magnitude = data["total_force"].length()
    if total_force_magnitude > 0:
        data["weighted_grip"] = 0.0
        for i in contact_points.size():
            var force_ratio = contact_forces[i] / total_force_magnitude
            data["weighted_grip"] += contact_grips[i] * force_ratio
    
    data["contact_data"] = {
        "position": data["average_position"],
        "normal": data["average_normal"],
        "distance": (data["average_position"] - global_transform.origin).length()
    }
    
    return data

func apply_to_suspension(data: Dictionary):
    if not suspension_system: return
    
    suspension_system.tire_radius = tire_diameter / 2.0
    suspension_system.tire_width = tire_width
    suspension_system.min_effective_radius = rim_diameter / 2.0
    
    if data["contact_points"] and data["contact_points"].size() > 0:
        suspension_system.raycast.global_transform.origin = data["average_position"]
        suspension_system.raycast.cast_to = data["average_normal"] * -1.0
    
    suspension_system.total_load = data["total_force"].y
    
    var lateral_force_ratio = abs(data["total_force"].x) / max(1.0, data["total_force"].y)
    suspension_system.lateral_deformation = lateral_force_ratio * tire_width * 0.1
    
    suspension_system.update_effective_radius(0.0, data["max_pressure"])

func apply_to_wheel(data: Dictionary):
    if not wheel: return
    
    wheel.contact_area = data["contact_area"]
    wheel.set_ground_grip(data["weighted_grip"])
    
    wheel.apply_forces_to_vehicle(
        data["contact_data"],
        {
            "lateral": data["total_force"].x,
            "longitudinal": data["total_force"].z,
            "aligning_torque": data["total_torque"].y,
            "overturning_moment": data["total_torque"].x,
            "gyroscopic_torque": Vector3(0, 0, data["total_torque"].z)
        }
    )

func apply_to_tire_system(data: Dictionary):
    if not tire_system: return
    
    tire_system.total_load = data["total_force"].y
    tire_system.total_lateral_force = data["total_force"].x
    tire_system.total_longitudinal_force = data["total_force"].z
    tire_system.overturning_moment = data["total_torque"].x
    tire_system.aligning_torque = data["total_torque"].y
    tire_system.gyroscopic_torque = Vector3(0, 0, data["total_torque"].z)
    tire_system.contact_area = data["contact_area"]
    
    update_wear_and_temperature(data)

func update_wear_and_temperature(data: Dictionary):
    var delta = get_physics_process_delta_time()
    
    var slip = wheel_dynamics.wheel_slip_ratio
    var slip_angle = wheel_dynamics.wheel_slip_angle
    var angular_velocity = abs(wheel_dynamics.wheel_angular_velocity)
    
    var wear_rate = tire_system.base_wear_rate
    wear_rate *= 1.0 + (slip * 5.0) + (abs(slip_angle) * 3.0)
    wear_rate *= data["max_pressure"] / 10000.0
    
    if tire_system.temperature_wear_curve:
        wear_rate *= tire_system.temperature_wear_curve.interpolate_baked(tire_system.surface_temperature)
    
    tire_system.tire_wear = clamp(tire_system.tire_wear + wear_rate * delta, 0.0, 1.0)
    
    var heat_generation = tire_system.base_heat_generation
    heat_generation *= 1.0 + (slip * 3.0) + (abs(slip_angle) * 2.0)
    heat_generation *= data["total_force"].length() / 10000.0
    
    var surface_heat = heat_generation * 0.7
    var core_heat = heat_generation * 0.3
    
    tire_system.surface_temperature += surface_heat * delta
    tire_system.core_temperature += core_heat * delta
    
    var cooling = tire_system.cooling_rate * (tire_system.ambient_temperature - tire_system.surface_temperature)
    tire_system.surface_temperature += cooling * delta
    tire_system.core_temperature += (cooling * 0.5) * delta
    
    update_aquaplaning_effects()
    update_zone_grip_from_tire_wear()

func update_aquaplaning_effects():
    if not tire_system: return
    
    if tire_system.water_depth > tire_system.aquaplaning_threshold:
        for zone in zone_grip_factors:
            var angle = float(zone) / radial_zones * TAU
            var water_risk = tire_system.aquaplaning_risk_curve.interpolate_baked(angle)
            zone_grip_factors[zone] = 1.0 - water_risk
    else:
        for zone in zone_grip_factors:
            zone_grip_factors[zone] = 1.0

func update_zone_grip_from_tire_wear():
    if not tire_system: return
    
    for zone in zone_grip_factors:
        var zone_wear = tire_system.tire_wear * (0.8 + abs(sin(zone * 0.5)) * 0.2)
        zone_grip_factors[zone] = 1.0 - zone_wear

func apply_clipping_forces(body: RigidBody3D):
    if not body: return
    
    var ratio = get_clipping_ratio(body)
    var force_magnitude = stiffness_curve.interpolate_baked(ratio) if stiffness_curve else pow(ratio, 2) * stiffness
    
    var local_pos = body.global_transform.origin - global_transform.origin
    local_pos = global_transform.basis.xform_inv(local_pos)
    var radial_pos = fmod(local_pos.angle_to(Vector3.UP), TAU) / TAU
    var zone = int(radial_pos * radial_zones)
    var grip_factor = zone_grip_factors.get(zone, 1.0)
    
    var force_dir = (global_transform.origin - body.global_transform.origin).normalized()
    var force = force_dir * force_magnitude * grip_factor
    
    body.apply_central_force(force)

func get_clipping_ratio(body: Node3D) -> float:
    var body_y = body.global_transform.origin.y
    var area_y = clipping_area.global_transform.origin.y
    var depth = clamp(area_y - body_y, 0.0, max_penetration_depth)
    return depth / max_penetration_depth

func _physics_process(delta):
    update_contact_data()
    var unified_data = calculate_unified_data()
    
    apply_to_suspension(unified_data)
    apply_to_wheel(unified_data)
    apply_to_tire_system(unified_data)
    
    for body in clipping_area.get_overlapping_bodies():
        if body is RigidBody3D:
            apply_clipping_forces(body)