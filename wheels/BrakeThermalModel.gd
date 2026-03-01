class_name BrakeThermalModel
extends Node

export var convection_coefficient := 15.0
export var radiation_coefficient := 0.000001
export var disc_to_pad_conductivity := 100.0
export var pad_to_caliper_conductivity := 50.0
export(Curve) var wheel_heat_resistance_curve
export(Curve) var hydraulic_efficiency_curve
export(Curve) var pad_wear_curve

var aerodynamic_blockage := 0.0
var ambient_temperature := 20.0
var ambient_air_velocity := 30.0  # m/s default

var disc_temperature := 20.0
var pad_temperature := 20.0
var caliper_temperature := 20.0
var accumulated_heat := 0.0
var brake_system: BrakeSystem

func setup(brake: BrakeSystem):
    brake_system = brake
    ambient_temperature = brake_system.ambient_temperature

func add_heat(heat: float):
    accumulated_heat += heat

func set_aerodynamic_blockage(blockage: float):
    aerodynamic_blockage = clamp(blockage, 0.0, 1.0)

func set_ambient_temperature(temp: float):
    ambient_temperature = temp

func update(delta: float):
    var resistance_factor = 1.0
    if wheel_heat_resistance_curve:
        resistance_factor = wheel_heat_resistance_curve.interpolate_baked(disc_temperature)
    
    var convection_effectiveness = clamp(ambient_air_velocity / 60.0, 0.2, 1.0)
    
    # Aplicar calor gerado
    disc_temperature += accumulated_heat * 0.7 / (brake_system.disc_mass * brake_system.disc_specific_heat)
    pad_temperature += accumulated_heat * 0.3 / (brake_system.disc_mass * brake_system.disc_specific_heat * 0.5)

    # Condução entre disco e pastilha
    var disc_pad_diff = disc_temperature - pad_temperature
    disc_temperature -= disc_pad_diff * disc_to_pad_conductivity * delta * resistance_factor
    pad_temperature += disc_pad_diff * disc_to_pad_conductivity * delta * resistance_factor

    # Condução para pinça
    var pad_caliper_diff = pad_temperature - caliper_temperature
    pad_temperature -= pad_caliper_diff * pad_to_caliper_conductivity * delta
    caliper_temperature += pad_caliper_diff * pad_to_caliper_conductivity * delta

    # Resfriamento por convecção e radiação
    disc_temperature -= convection_coefficient * convection_effectiveness * (disc_temperature - ambient_temperature) * delta
    disc_temperature -= radiation_coefficient * (pow(disc_temperature, 4) - pow(ambient_temperature, 4)) * delta

    # Atualizar sistema principal
    brake_system.disc_temperature = disc_temperature
    brake_system.pad_temperature = pad_temperature
    
    # Efeito de empenamento
    if brake_system.disc_warp_curve:
        brake_system.disc_warp = brake_system.disc_warp_curve.interpolate_baked(disc_temperature)
    
    # Eficiência hidráulica
    var hydraulic_eff = 1.0
    if hydraulic_efficiency_curve:
        hydraulic_eff = hydraulic_efficiency_curve.interpolate_baked(caliper_temperature)
    
    brake_system.max_brake_torque = brake_system.original_brake_torque * hydraulic_eff * brake_system.material_strength

    # Desgaste da pastilha
    var wear_factor = 1.0
    if pad_wear_curve:
        wear_factor = pad_wear_curve.interpolate_baked(pad_temperature)
    
    brake_system.pad_thickness -= delta * brake_system.pad_wear_rate * wear_factor

    accumulated_heat = 0.0