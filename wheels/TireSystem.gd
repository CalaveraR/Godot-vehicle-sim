class_name TireSystem
extends Node

export var max_friction = 1.5
export var base_lateral_stiffness = 30000.0
export var base_camber_stiffness = 1000.0
export var base_carcass_stiffness = 10000.0
export var pneumatic_trail_max = 0.03
export var base_wear_rate = 0.00001
export var base_heat_generation = 0.0001
export var flex_heat_factor = 0.0005
export var cooling_rate = 0.1
export var ambient_temperature = 20.0
export var tire_pressure = 220.0
export var min_tire_wear = 0.1
export var ground_grip_factor = 1.0
export var water_depth = 0.0
export var aquaplaning_threshold = 0.005
export var track_texture = 1.0
export var contact_area = 0.02
export(Curve) var temperature_wear_curve
export(Curve) var slip_angle_curve_180
export(Curve) var pressure_variation_curve
export(Curve) var contamination_grip_curve
export(Curve) var cold_tire_grip_curve
export(Curve) var carcass_flex_x_curve
export(Curve) var carcass_flex_y_curve
export(Curve) var carcass_flex_z_curve
export(Curve) var tread_deflection_curve
export(Curve) var longitudinal_curve
export(Curve) var lateral_curve
export(Curve) var combined_slip_curve
export(Curve) var load_sensitivity_curve
export(Curve) var temperature_friction_curve
export(Curve) var pressure_friction_curve
export(Curve) var camber_curve
export(Curve) var pneumatic_trail_curve
export(Curve) var aligning_torque_curve
export(Curve) var track_texture_wear_curve
export(Curve) var reverse_aligning_curve
export(Curve) var compound_hardness_curve
export(Curve) var aquaplaning_risk_curve

var surface_temperature = 20.0
var core_temperature = 20.0
var tire_wear = 1.0
var asymmetric_wear = 0.0
var directional_wear = Vector2(1.0, 1.0)
var compound_hardness = 1.0
var aquaplaning_factor = 1.0
var breakaway_counter = 0.0
var total_lateral_force = 0.0
var total_longitudinal_force = 0.0
var aligning_torque = 0.0
var overturning_moment = 0.0
var gyroscopic_torque = Vector3.ZERO
var thermal_conductivity = 0.5
var carcass_deflection = Vector3.ZERO
var tread_deflection = 0.0
var contact_patch_deformation = Vector2.ZERO
var pressure_variation = 0.0
var thermal_expansion = 0.0
var cold_grip_factor = 1.0
var contamination_level = 0.0
var leak_rate = 0.0
var heat_conduction_to_wheel = 0.0
var puncture_size = 0.0
var original_pressure = 220.0

signal tire_screech(intensity)
signal aquaplaning_started
signal aquaplaning_ended

onready var thermal_model = $ThermalModel
onready var wear_model = $WearModel
onready var aquaplaning_model = $AquaplaningModel
onready var gyroscopic_model = $GyroscopicModel
onready var deformation_model = $DeformationModel

func _ready():
    original_pressure = tire_pressure
    thermal_model.setup(self)
    wear_model.setup(self)
    aquaplaning_model.setup(self)
    gyroscopic_model.setup(self)
    deformation_model.setup(self)

func update(delta: float, total_load: float, wheel_slip_ratio: float, wheel_slip_angle: float, 
           wheel_angular_velocity: float, static_camber: float, car_body: RigidBody, 
           effective_radius: float, relaxation_factor: float, lateral_deformation: float):
    
    thermal_model.update(delta, total_load, wheel_slip_ratio, wheel_slip_angle, wheel_angular_velocity)
    wear_model.update(delta, total_load, wheel_slip_ratio, wheel_slip_angle, wheel_angular_velocity)
    aquaplaning_model.update(delta, car_body)
    deformation_model.update(delta, total_load, wheel_slip_ratio, wheel_slip_angle, relaxation_factor)
    
    update_pressure(delta)
    cold_grip_factor = cold_tire_grip_curve.interpolate_baked(thermal_model.surface_temperature) if cold_tire_grip_curve else 1.0

func update_pressure(delta: float):
    if pressure_variation_curve:
        var pressure_change = pressure_variation_curve.interpolate_baked(core_temperature)
        tire_pressure += pressure_change * delta
    
    tire_pressure = max(0, tire_pressure - leak_rate * delta)
    
    if pressure_friction_curve:
        pressure_variation = pressure_friction_curve.interpolate_baked(tire_pressure)
    
    base_lateral_stiffness = base_lateral_stiffness * (tire_pressure / original_pressure)

func apply_puncture(severity: float):
    puncture_size = clamp(puncture_size + severity, 0.0, 1.0)
    leak_rate = puncture_size * 10.0

func accumulate_contamination(delta, surface_data):
    contamination_level += surface_data.contamination_rate * delta
    contamination_level = clamp(contamination_level, 0.0, 1.0)
    
    var grip_reduction = 0.0
    match surface_data.contamination_type:
        1: grip_reduction = contamination_level * 0.3
        2: grip_reduction = contamination_level * 0.6
        3: grip_reduction = contamination_level * 0.8
        
    ground_grip_factor = 1.0 - grip_reduction

func get_tire_health() -> Vector3:
    return Vector3(tire_wear, surface_temperature, core_temperature)

func get_aquaplaning_factor() -> float:
    return aquaplaning_factor

func get_compound_hardness() -> float:
    return compound_hardness

func get_carcass_deflection() -> Vector3:
    return carcass_deflection

func get_tread_deflection() -> float:
    return tread_deflection

func get_contact_patch_deformation() -> Vector2:
    return contact_patch_deformation

func set_water_depth(depth: float):
    water_depth = depth

func set_track_texture(texture: float):
    track_texture = texture

func set_ground_grip(factor: float):
    ground_grip_factor = factor

func set_thermal_conductivity(conductivity: float):
    thermal_conductivity = conductivity

func set_tire_pressure(pressure: float):
    tire_pressure = pressure