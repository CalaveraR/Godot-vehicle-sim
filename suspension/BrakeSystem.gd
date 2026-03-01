class_name BrakeSystem
extends Node

export var max_brake_torque = 1500.0
export var handbrake_torque = 2000.0
export var brake_balance = 0.6
export var disc_mass = 5.0
export var disc_specific_heat = 480.0
export var pad_wear_rate = 0.00001
export var min_pad_thickness = 2.0
export(Curve) var brake_fade_curve
export(Curve) var pad_friction_temp_curve
export(Curve) var disc_warp_curve

# Novas propriedades para modelo térmico estendido
export(Curve) var wheel_heat_resistance_curve
export(Curve) var hydraulic_efficiency_curve
export(Curve) var pad_wear_curve
export var convection_coefficient = 15.0
export var radiation_coefficient = 0.000001
export var disc_to_pad_conductivity = 100.0
export var pad_to_caliper_conductivity = 50.0

var current_brake_torque = 0.0
var handbrake_active = false
var brake_temperature = 0.0
var disc_temperature = 0.0
var pad_thickness = 10.0
var pad_temperature = 0.0
var caliper_temperature = 0.0
var disc_warp = 0.0
var disc_wear = 0.0
var thermal_fatigue = 0.0
var material_strength = 1.0
var original_brake_torque = 1500.0
var accumulated_heat = 0.0
var ambient_air_velocity = 30.0  # m/s default

func _ready():
    original_brake_torque = max_brake_torque
    # Não há mais necessidade do thermal_model externo
    # Toda a lógica térmica está integrada aqui

func apply_brake(brake_percentage: float):
    current_brake_torque = brake_percentage * max_brake_torque
    # Calcular calor gerado
    accumulated_heat += brake_percentage * max_brake_torque * 0.1

func set_handbrake(active: bool):
    handbrake_active = active
    if active:
        accumulated_heat += handbrake_torque * 0.1

func update(delta: float):
    update_thermal_model(delta)  # Atualizar modelo térmico
    update_thermal_fatigue(delta)
    update_wear(delta)
    
    brake_temperature = disc_temperature  # Para compatibilidade

func update_thermal_model(delta: float):
    # Aplicar calor gerado
    disc_temperature += accumulated_heat * 0.7 / (disc_mass * disc_specific_heat)
    pad_temperature += accumulated_heat * 0.3 / (disc_mass * disc_specific_heat * 0.5)
    accumulated_heat = 0.0
    
    # Troca térmica entre componentes
    var resistance_factor = 1.0
    if wheel_heat_resistance_curve:
        resistance_factor = wheel_heat_resistance_curve.interpolate_baked(disc_temperature)
    
    var convection_effectiveness = clamp(ambient_air_velocity / 60.0, 0.2, 1.0)
    
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
    
    # Atualizar empenamento
    if disc_warp_curve:
        disc_warp = disc_warp_curve.interpolate_baked(disc_temperature)
    
    # Eficiência hidráulica
    var hydraulic_eff = 1.0
    if hydraulic_efficiency_curve:
        hydraulic_eff = hydraulic_efficiency_curve.interpolate_baked(caliper_temperature)
    
    max_brake_torque = original_brake_torque * hydraulic_eff * material_strength

func update_wear(delta: float):
    # Desgaste da pastilha
    var wear_factor = 1.0
    if pad_wear_curve:
        wear_factor = pad_wear_curve.interpolate_baked(pad_temperature)
    
    pad_thickness -= delta * pad_wear_rate * wear_factor * current_brake_torque / max_brake_torque
    
    # Desgaste do disco
    disc_wear += delta * 0.00001 * disc_temperature / 100.0

func update_thermal_fatigue(delta: float):
    var temp_factor = clamp(disc_temperature / 1000.0, 0.0, 1.0)
    thermal_fatigue += temp_factor * delta * 0.01
    material_strength = 1.0 - thermal_fatigue
    
    if thermal_fatigue > 0.8 && randf() < 0.001:
        catastrophic_failure()

func catastrophic_failure():
    max_brake_torque *= 0.2
    disc_warp = 0.8

func get_brake_torque() -> float:
    var torque = current_brake_torque
    if handbrake_active:
        torque += handbrake_torque
    
    var fade_factor = 1.0
    if brake_fade_curve:
        fade_factor = brake_fade_curve.interpolate_baked(disc_temperature / 1000.0)
    
    var warp_factor = 1.0 - disc_warp * 0.5
    var pad_wear_factor = clamp(pad_thickness / min_pad_thickness, 0.2, 1.0)
    
    return torque * brake_balance * fade_factor * warp_factor * pad_wear_factor

# Funções para integração com ambiente
func set_air_velocity(velocity: float):
    ambient_air_velocity = velocity

func set_ambient_temperature(temp: float):
    ambient_temperature = temp

# Função para debug
func get_brake_temperatures() -> Vector3:
    return Vector3(disc_temperature, pad_temperature, caliper_temperature)