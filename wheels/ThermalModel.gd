class_name ThermalModel
extends Node

export var specific_heat = 1500.0
export var thermal_mass = 10.0
export var conductivity_to_wheel = 50.0
export var convection_coefficient = 25.0
export(Curve) var temp_conductivity_curve

var surface_temperature = 20.0
var core_temperature = 20.0
var internal_heat = 0.0
var heat_to_wheel = 0.0
var heat_to_atmosphere = 0.0
var tire_system: TireSystem

func setup(tire: TireSystem):
    tire_system = tire

func update(delta: float, total_load: float, slip_ratio: float, slip_angle: float, angular_velocity: float):
    var slip_heat = (abs(slip_ratio) + abs(slip_angle)) * tire_system.base_heat_generation * delta
    var flex_heat = total_load * tire_system.flex_heat_factor * delta
    var speed_heat = angular_velocity * 0.0005 * delta
    
    internal_heat = slip_heat + flex_heat + speed_heat
    
    var temp_diff = core_temperature - surface_temperature
    var conductivity = temp_conductivity_curve.interpolate_baked(avg_temp()) if temp_conductivity_curve else conductivity_to_wheel
    heat_to_wheel = conductivity * temp_diff * delta
    
    heat_to_atmosphere = convection_coefficient * (surface_temperature - tire_system.ambient_temperature) * delta
    
    core_temperature += (internal_heat - heat_to_wheel) / (thermal_mass * specific_heat)
    surface_temperature += (heat_to_wheel - heat_to_atmosphere) / (thermal_mass * 0.5 * specific_heat)
    
    core_temperature = min(core_temperature, 300.0)
    surface_temperature = min(surface_temperature, 250.0)
    
    tire_system.surface_temperature = surface_temperature
    tire_system.core_temperature = core_temperature

func avg_temp() -> float:
    return (surface_temperature + core_temperature) * 0.5