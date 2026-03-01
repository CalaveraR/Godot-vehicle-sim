class_name Drivetrain
extends Node

signal failure
signal backlash_impact(intensity)

# Configuração
export(float) var base_backlash = 0.05
export(float) var base_stiffness = 1000.0
export(float) var base_damping = 50.0
export(float) var max_fluid_temp = 120.0
export(float) var viscosity = 0.05
export(Curve) var viscosity_curve
export(Curve) var thermal_efficiency_curve

# Referência ao tipo de engrenagem da transmissão
var transmission_gear_type = Transmission.GearType.HELICAL

# Estado
var output_torque = 0.0
var output_rpm = 0.0
var fluid_temp = 30.0
var vibration_level = 0.0
var deflection = 0.0
var velocity = 0.0
var catastrophic_failure = false

func configure_curves():
    if !viscosity_curve:
        viscosity_curve = Curve.new()
        viscosity_curve.add_point(Vector2(0.0, 1.0))
        viscosity_curve.add_point(Vector2(0.5, 0.7))
        viscosity_curve.add_point(Vector2(1.0, 0.3))
    
    if !thermal_efficiency_curve:
        thermal_efficiency_curve = Curve.new()
        thermal_efficiency_curve.add_point(Vector2(0.0, 1.0))
        thermal_efficiency_curve.add_point(Vector2(0.8, 0.9))
        thermal_efficiency_curve.add_point(Vector2(1.0, 0.7))

func update(delta, input_torque, input_rpm):
    if catastrophic_failure:
        output_torque = 0.0
        return
    
    # Ajustar propriedades baseadas no tipo de engrenagem
    var current_backlash = base_backlash
    var current_stiffness = base_stiffness
    var current_damping = base_damping
    var impact_factor = 1.0
    
    if transmission_gear_type == Transmission.GearType.STRAIGHT:
        # Engrenagens retas: maior folga, maior rigidez, menor amortecimento
        current_backlash = 0.08
        current_stiffness = 1500.0
        current_damping = 30.0
        impact_factor = 1.3  # Impactos mais intensos mas menos danosos
    else:
        # Engrenagens helicoidais: menor folga, menor rigidez
        current_backlash = 0.03
        current_stiffness = 800.0
        current_damping = 60.0
        impact_factor = 0.8  # Impactos menos intensos mas mais danosos
    
    # Modelo de backlash
    var spring_force = current_stiffness * deflection
    var damper_force = current_damping * velocity
    var net_torque = input_torque - spring_force - damper_force
    var acceleration = net_torque / 0.1  # Inércia simplificada
    
    velocity += acceleration * delta
    deflection += velocity * delta
    
    # Limitar pela folga e emitir sinal de impacto
    if abs(deflection) > current_backlash:
        deflection = current_backlash * sign(deflection)
        velocity = 0.0
        var impact_intensity = min(abs(velocity) / 100.0, 1.0) * impact_factor
        emit_signal("backlash_impact", impact_intensity)
    
    output_torque = spring_force
    
    # Perda por viscosidade
    var viscosity_factor = viscosity_curve.interpolate(fluid_temp / max_fluid_temp)
    var viscous_loss = input_rpm * 0.1047 * viscosity * viscosity_factor * delta
    output_torque -= viscous_loss
    
    # Eficiência térmica
    var efficiency = thermal_efficiency_curve.interpolate(fluid_temp / max_fluid_temp)
    output_torque *= efficiency
    
    # Atualizar temperatura
    fluid_temp += abs(input_torque) * delta * 0.001
    fluid_temp = clamp(fluid_temp, 30.0, max_fluid_temp * 1.2)
    
    # Falha catastrófica (menos provável em engrenagens retas)
    var failure_chance = 0.001
    if transmission_gear_type == Transmission.GearType.STRAIGHT:
        failure_chance *= 0.6  # 40% menos chance de falha
    
    if fluid_temp > max_fluid_temp && randf() < failure_chance:
        catastrophic_failure = true
        emit_signal("failure")

func apply_backlash_shock():
    # Impacto mais forte para engrenagens retas
    var intensity = 0.8
    if transmission_gear_type == Transmission.GearType.STRAIGHT:
        intensity = 1.2
    
    velocity += 50.0
    vibration_level = min(vibration_level + 0.5 * intensity, 2.0)
    emit_signal("backlash_impact", intensity)

func get_fluid_temperature() -> float:
    return fluid_temp

func get_vibration_level() -> float:
    return vibration_level