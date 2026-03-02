class_name Wheel
extends Node

enum Gear { REVERSE = -1, NEUTRAL = 0, DRIVE = 1 }

@onready var suspension = $SuspensionSystem
@onready var tire = $TireSystem
@onready var brake = $BrakeSystem
@onready var dynamics = $WheelDynamics
@onready var flat_spot = $FlatSpotSystem
@onready var suspension_response = $SuspensionResponseSystem
@onready var wheel_assembly = $WheelAssemblySystem
@onready var tire_runtime = get_node_or_null("TireRuntimeCoordinator") if has_node("TireRuntimeCoordinator") else get_node_or_null("HybridTireSystem")

var current_engine_torque = 0.0
var gear = Gear.DRIVE
var car_body = null
var thermal_deformation = 0.0
var tire_bubble = 0.0
var max_engine_torque = 500.0

signal tire_screech(intensity)
signal aquaplaning_started
signal aquaplaning_ended
signal flat_spot_sound(intensity)

func _ready():
    car_body = get_parent()
    wheel_assembly.apply_to_systems()

func _physics_process(delta):
    var lateral_g = 0.0
    if car_body:
        lateral_g = car_body.linear_velocity.cross(car_body.angular_velocity).y / 9.81
    
    suspension_response.calculate_dynamic_response(car_body, suspension.total_load, lateral_g)
    suspension_response.apply_response(suspension)
    
    var unified_data: ContactPatchData = ContactPatchData.new()
    if tire_runtime:
        if tire_runtime.has_method("step_runtime_pipeline"):
            unified_data = tire_runtime.step_runtime_pipeline(delta, true)
        else:
            tire_runtime.update_contact_data()
            unified_data = tire_runtime.calculate_unified_data()
            tire_runtime.apply_to_suspension(unified_data)
            tire_runtime.apply_to_wheel(unified_data)
            tire_runtime.apply_to_tire_system(unified_data, delta)
    
    var flat_spot_depth = flat_spot.get_flat_spot_depth()
    suspension.update_effective_radius(flat_spot_depth, unified_data.max_pressure)
    
    brake.update(delta)
    
    flat_spot.update(
        delta,
        dynamics.get_angular_velocity(),
        dynamics.is_dragging,
        tire.surface_temperature,
        suspension.total_load
    )
    
    var flat_spot_torque_factor = flat_spot.get_torque_factor(
        dynamics.get_angular_velocity(),
        suspension.total_load
    )
    
    dynamics.update(
        delta,
        current_engine_torque * gear * flat_spot_torque_factor,
        brake.get_brake_torque(),
        suspension.total_load,
        suspension.get_relaxation_factor(),
        car_body,
        unified_data.contact_data,
        global_transform
    )
    
    tire.update(
        delta,
        suspension.total_load,
        dynamics.get_wheel_slip().x,
        dynamics.get_wheel_slip().y,
        dynamics.get_angular_velocity(),
        suspension.get_dynamic_camber(),
        car_body,
        suspension.get_effective_radius(),
        suspension.get_relaxation_factor(),
        suspension.get_lateral_deformation()
    )
    
    var tire_deformation = tire.get_contact_patch_deformation()
    var vibration_level = flat_spot.get_vibration() * (1.0 - suspension.get_absorbed_vibration())
    suspension.respond_to_tire_elasticity(tire_deformation, vibration_level)
    
    suspension.update_suspension_geometry(suspension.total_load)
    
    sync_with_surface()
    process_effects_and_signals(delta)
    
    if suspension.suspension_type == SuspensionSystem.SUSPENSION_TYPE.SOLID_AXLE:
        suspension.update_suspension_geometry(suspension.total_load)
    
    if suspension.suspension_type == SuspensionSystem.SUSPENSION_TYPE.AIR:
        var temp_factor = 1.0 - (tire.core_temperature - 20.0) * 0.01
        suspension.air_pressure *= temp_factor

func sync_with_surface():
    if Engine.has_singleton("SurfaceManager"):
        var sm = Engine.get_singleton("SurfaceManager")
        var wheel_pos = global_transform.origin
        
        tire.set_water_depth(sm.get_water_depth(wheel_pos))
        
        var surface_data = sm.get_surface_data(wheel_pos)
        tire.set_track_texture(surface_data.texture_type)
        tire.accumulate_contamination(get_physics_process_delta_time(), surface_data)
        
        if surface_data.has("temperature"):
            tire.ambient_temperature = surface_data.temperature
        
        if surface_data.has("grip_factor"):
            tire.set_ground_grip(surface_data.grip_factor)

func process_effects_and_signals(delta):
    if tire.breakaway_counter > 0.3 and abs(dynamics.wheel_slip_angle) > 0.5:
        emit_signal("tire_screech", min(tire.breakaway_counter, 1.0))
    
    var vibration = flat_spot.get_vibration()
    if vibration > 0.01:
        emit_signal("flat_spot_sound", flat_spot.get_sound_intensity())
    
    update_thermal_deformation(delta)
    update_tire_bubble(delta)

func update_thermal_deformation(delta: float):
    if tire.surface_temperature > 100:
        thermal_deformation = (tire.surface_temperature - 100) * 0.0001

func update_tire_bubble(delta: float):
    if tire.surface_temperature > 150 and randf() < 0.01:
        tire_bubble = min(1.0, tire_bubble + 0.05)
    elif tire_bubble > 0:
        tire_bubble = max(0.0, tire_bubble - 0.01 * delta)

func apply_forces_to_vehicle(contact_data: Dictionary, forces: Dictionary):
    if not contact_data: return
    
    var application_point = contact_data["position"]
    var force_vector = Vector3(forces["lateral"], suspension.total_load, forces["longitudinal"])
    var global_force = global_transform.basis.xform(force_vector)
    
    car_body.add_force(global_force, application_point - car_body.global_transform.origin)
    car_body.add_torque(Vector3(0, forces["aligning_torque"], 0))
    car_body.add_torque(Vector3(forces["overturning_moment"], 0, 0))
    car_body.add_torque(forces["gyroscopic_torque"])
    
    var vibration = flat_spot.get_vibration()
    if vibration > 0.01:
        var vibration_force = Vector3(
            randf_range(-1, 1),
            randf_range(-1, 1),
            randf_range(-1, 1)
        ) * vibration * 100.0
        car_body.apply_central_impulse(vibration_force * get_physics_process_delta_time())

func set_steering_angle(angle: float):
    suspension.dynamic_toe = angle

func set_engine_torque(torque_percentage: float):
    current_engine_torque = clamp(torque_percentage, 0.0, 1.0) * max_engine_torque

func set_brake_force(brake_percentage: float):
    brake.apply_brake(brake_percentage)

func set_handbrake(active: bool):
    brake.set_handbrake(active)

func set_gear(new_gear: int):
    gear = new_gear

func set_camber(angle: float):
    suspension.dynamic_camber = angle

func set_tire_pressure(pressure: float):
    tire.set_tire_pressure(pressure)

func set_ground_grip(factor: float):
    tire.set_ground_grip(factor)

func set_track_texture(texture_type: float):
    tire.set_track_texture(texture_type)

func set_water_depth(depth: float):
    tire.set_water_depth(depth)

func set_thermal_conductivity(conductivity: float):
    tire.set_thermal_conductivity(conductivity)

func set_vibration_transmission(factor: float):
    flat_spot.vibration_transmission = factor

func start_dragging():
    dynamics.set_dragging(true)

func stop_dragging():
    dynamics.set_dragging(false)

func apply_puncture(severity: float):
    tire.apply_puncture(severity)

func get_contact_force() -> Vector3:
    return Vector3(tire.total_lateral_force, suspension.total_load, tire.total_longitudinal_force)

func get_torque_feedback() -> float:
    return -tire.total_longitudinal_force * suspension.get_effective_radius()

func get_gyroscopic_torque() -> Vector3:
    return tire.gyroscopic_torque

func get_aligning_torque() -> float:
    return tire.aligning_torque

func get_overturning_moment() -> float:
    return tire.overturning_moment

func get_wheel_slip() -> Vector2:
    return dynamics.get_wheel_slip()

func get_tire_health() -> Vector3:
    return tire.get_tire_health()

func get_tire_temperatures() -> Vector2:
    return Vector2(tire.surface_temperature, tire.core_temperature)

func get_vibration_level() -> float:
    return flat_spot.get_vibration()

func get_aquaplaning_factor() -> float:
    return tire.get_aquaplaning_factor()

func get_compound_hardness() -> float:
    return tire.get_compound_hardness()

func get_lateral_deformation() -> float:
    return suspension.get_lateral_deformation()

func get_flat_spot_depth() -> float:
    return flat_spot.get_flat_spot_depth()

func get_wheel_spec() -> String:
    return wheel_assembly.get_spec_string()

func get_wheel_properties() -> Dictionary:
    return wheel_assembly.get_properties()

func adjust_suspension(height: float):
    if suspension.suspension_type == SuspensionSystem.SUSPENSION_TYPE.AIR:
        suspension.adjust_ride_height(height)