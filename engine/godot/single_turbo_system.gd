class_name SingleTurboSystem
extends InductionSystem

var turbo_response_rate: float = 0.0
var boost_target: float = 1.0
var vgt_position: float = 0.5
var compressor_outlet_temp: float = 0.0

func _init(system: TurboSystem):
    turbo_system = system
    if turbo_system.anti_lag_system_installed:
        anti_lag_system = AntiLagSystem.new(turbo_system)

func update(delta: float, rpm: float, throttle: float):
    var rpm_normalized = turbo_system.get_rpm_normalized()
    calculate_boost_target(rpm_normalized)
    
    if anti_lag_system:
        anti_lag_system.update(delta, rpm_normalized)
    
    apply_turbo_lag(delta, rpm_normalized)
    update_vgt_position(delta, rpm_normalized)
    calculate_backpressure(rpm_normalized)
    calculate_turbo_load_factor(rpm_normalized)
    update_turbo_efficiency(rpm_normalized)
    calculate_compressor_temperature()
    apply_intercooler()

func calculate_boost_target(rpm_normalized: float):
    if turbo_system.boost_curve:
        boost_target = turbo_system.boost_curve.interpolate(rpm_normalized)
    else:
        boost_target = 1.0 + turbo_system.max_boost_pressure * smoothstep(0.3, 0.7, rpm_normalized)
    boost_target = lerp(1.0, boost_target, turbo_system.engine_throttle)
    boost_target = min(boost_target, 1.0 + turbo_system.max_boost_pressure)

func apply_turbo_lag(delta: float, rpm_normalized: float):
    if turbo_system.spool_response_curve:
        turbo_response_rate = turbo_system.spool_response_curve.interpolate(rpm_normalized)
    else:
        turbo_response_rate = lerp(0.5, 2.0, rpm_normalized)
    
    if turbo_system.turbo_undersized: turbo_response_rate *= 1.5
    elif turbo_system.turbo_oversized: turbo_response_rate *= 0.5
    
    turbo_spooled = turbo_system.engine_rpm > turbo_system.calculate_spool_rpm()
    
    var boost_difference = boost_target - current_boost
    var response = turbo_response_rate * delta
    
    if boost_difference > 0:
        current_boost += min(boost_difference, response)
    else:
        current_boost += max(boost_difference, -response * 2)
    
    current_boost = max(current_boost, 1.0)

func update_vgt_position(delta: float, rpm_normalized: float):
    if turbo_system.vgt_mode == turbo_system.VGTMode.FIXED:
        return
    
    var target_position = vgt_position
    
    if turbo_system.vgt_position_curve:
        target_position = turbo_system.vgt_position_curve.interpolate(rpm_normalized)
    else:
        target_position = lerp(turbo_system.vgt_max_position, turbo_system.vgt_min_position, rpm_normalized)
    
    var boost_factor = clamp((current_boost - 1.0) / turbo_system.max_boost_pressure, 0.0, 1.0)
    target_position = lerp(target_position, turbo_system.vgt_min_position, boost_factor * 0.5)
    
    vgt_position = lerp(
        vgt_position, 
        clamp(target_position, turbo_system.vgt_min_position, turbo_system.vgt_max_position), 
        delta * 5.0
    )
    
    var vgt_response_factor = 1.0 - abs(vgt_position - 0.5) * 0.7
    turbo_response_rate *= vgt_response_factor

func calculate_backpressure(rpm_normalized: float):
    var base_backpressure = 1.0
    if turbo_system.backpressure_curve:
        base_backpressure = turbo_system.backpressure_curve.interpolate(rpm_normalized)
    
    var boost_factor = 1.0 + (current_boost - 1.0) * 0.5
    var rpm_factor = 1.0 + rpm_normalized * 0.3
    
    var turbo_size_factor = 1.5 - (turbo_system.turbine_size / 100.0)
    
    current_backpressure = base_backpressure * boost_factor * rpm_factor * turbo_size_factor
    
    turbo_surge = false
    if current_backpressure > current_boost * 2.5 && turbo_system.engine_throttle < 0.3:
        turbo_surge = true
        current_boost *= 0.95

func calculate_turbo_load_factor(rpm_normalized: float):
    var rpm_factor = clamp((turbo_system.engine_rpm - turbo_system.idle_rpm) / (turbo_system.redline_rpm - turbo_system.idle_rpm), 0.0, 1.0)
    var boost_factor = clamp((current_boost - 1.0) / turbo_system.max_boost_pressure, 0.0, 1.0)
    var ideal_load = rpm_factor * boost_factor
    
    if turbo_system.turbo_oversized && rpm_factor < 0.4:
        ideal_load *= 0.5
    elif turbo_system.turbo_undersized && rpm_factor > 0.7:
        ideal_load *= 0.8
    
    turbo_load_factor = ideal_load * 2 - 1
    
    if current_boost < 1.0 && turbo_system.engine_throttle > 0:
        turbo_load_factor = -1.0 + (current_boost * 2)

func update_turbo_efficiency(rpm_normalized: float):
    if turbo_system.turbo_efficiency_curve:
        current_efficiency = turbo_system.turbo_efficiency_curve.interpolate(turbo_load_factor)
    else:
        current_efficiency = 0.7 + 0.3 * (1.0 - abs(turbo_load_factor))
    
    var rpm_factor = turbo_system.engine_rpm / turbo_system.redline_rpm
    if rpm_factor < 0.2:
        current_efficiency *= lerp(0.8, 1.0, rpm_factor * 5)
    elif rpm_factor > 0.9:
        current_efficiency *= lerp(1.0, 0.85, (rpm_factor - 0.9) * 10)
    
    var temp_factor = 1.0 - clamp((intake_temperature - turbo_system.AMBIENT_TEMPERATURE) / 50.0, 0.0, 0.3)
    current_efficiency *= temp_factor
    
    var backpressure_efficiency = 1.0 - (current_backpressure - 1.0) * 0.1
    current_efficiency *= clamp(backpressure_efficiency, 0.7, 1.0)
    current_efficiency = clamp(current_efficiency, 0.5, 1.5)

func calculate_compressor_temperature():
    var pressure_ratio = current_boost
    var gamma = 1.4  # Índice adiabático para o ar
    var temp_ratio = pow(pressure_ratio, (gamma - 1.0) / gamma)
    var ideal_outlet_temp = turbo_system.AMBIENT_TEMPERATURE * temp_ratio
    
    var compressor_efficiency = 0.75  # Eficiência típica
    compressor_outlet_temp = turbo_system.AMBIENT_TEMPERATURE + (ideal_outlet_temp - turbo_system.AMBIENT_TEMPERATURE) / compressor_efficiency
    
    intake_temperature = compressor_outlet_temp

func apply_intercooler():
    # Simulação de intercooler (reduz temperatura em 30-60%)
    var intercooler_efficiency = 0.5
    var ambient_temp = turbo_system.AMBIENT_TEMPERATURE
    intake_temperature = ambient_temp + (intake_temperature - ambient_temp) * (1.0 - intercooler_efficiency)

func get_boost() -> float:
    return current_boost

func get_intake_temp() -> float:
    return intake_temperature

func get_data() -> Dictionary:
    var data = super.get_data()
    data["vgt_position"] = vgt_position
    data["compressor_temp"] = compressor_outlet_temp
    
    if anti_lag_system:
        data["anti_lag_active"] = anti_lag_system.active
        data["anti_lag_exhaust_pop"] = anti_lag_system.exhaust_pop
    else:
        data["anti_lag_active"] = false
        data["anti_lag_exhaust_pop"] = false
    
    data["type"] = "Turbocharger"
    return data

# Funções auxiliares
func smoothstep(edge0: float, edge1: float, x: float) -> float:
    var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)