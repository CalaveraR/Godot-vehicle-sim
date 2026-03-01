class_name Differential
extends Node

enum LSDType {OPEN, LIMITED_SLIP, LOCKED}

# Configuração
export(LSDType) var lsd_type = LSDType.LIMITED_SLIP
export(float) var max_temp = 120.0
export(Curve) var torque_split_curve
export(Curve) var bias_curve
export(Curve) var thermal_curve
export(Curve) var friction_curve

# Estado
var wheel_torques = [0.0, 0.0, 0.0, 0.0]
var temperature = 30.0
var vibration_level = 0.0

func configure_curves():
    if !torque_split_curve:
        torque_split_curve = Curve.new()
        torque_split_curve.add_point(Vector2(0.0, 0.3))
        torque_split_curve.add_point(Vector2(0.5, 0.5))
        torque_split_curve.add_point(Vector2(1.0, 0.7))
    
    if !bias_curve:
        bias_curve = Curve.new()
        bias_curve.add_point(Vector2(0.0, 1.0))
        bias_curve.add_point(Vector2(0.5, 1.5))
        bias_curve.add_point(Vector2(1.0, 2.0))
    
    if !thermal_curve:
        thermal_curve = Curve.new()
        thermal_curve.add_point(Vector2(0.0, 1.0))
        thermal_curve.add_point(Vector2(0.8, 0.9))
        thermal_curve.add_point(Vector2(1.0, 0.7))
    
    if !friction_curve:
        friction_curve = Curve.new()
        friction_curve.add_point(Vector2(0.0, 0.8))
        friction_curve.add_point(Vector2(1000.0, 1.2))
        friction_curve.add_point(Vector2(2000.0, 0.9))

func update(delta, input_torque):
    # Resfriamento
    temperature = lerp(temperature, 30.0, 0.05 * delta)
    
    # Distribuição de torque
    var speed = get_parent().linear_velocity.length()
    var split = torque_split_curve.interpolate(speed / 100.0)
    
    var front_torque = input_torque * split
    var rear_torque = input_torque * (1.0 - split)
    
    # Distribuir para rodas individuais
    wheel_torques[0] = front_torque * 0.5 * _get_bias_factor(0)
    wheel_torques[1] = front_torque * 0.5 * _get_bias_factor(1)
    wheel_torques[2] = rear_torque * 0.5 * _get_bias_factor(2)
    wheel_torques[3] = rear_torque * 0.5 * _get_bias_factor(3)
    
    # Aplicar efeito térmico
    if temperature > max_temp:
        var reduction = thermal_curve.interpolate((temperature - max_temp) / 50.0)
        for i in 4: wheel_torques[i] *= reduction
    
    # Atualizar vibração
    vibration_level = clamp(temperature / max_temp, 0.0, 1.0) * 0.3

func get_wheel_torque(wheel_index) -> float:
    return wheel_torques[wheel_index] if wheel_index < wheel_torques.size() else 0.0

func get_wheel_friction(wheel_index, wheel_load) -> float:
    return friction_curve.interpolate(wheel_load) if friction_curve else 1.0

func _get_bias_factor(wheel_index):
    return bias_curve.interpolate(float(wheel_index) / 4.0) if bias_curve else 1.0

func get_temperature() -> float:
    return temperature

func get_vibration_level() -> float:
    return vibration_level