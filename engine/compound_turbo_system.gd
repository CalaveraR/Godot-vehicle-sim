class_name CompoundTurboSystem
extends InductionSystem

var hp_boost: float = 1.0
var lp_boost: float = 1.0
var hp_spooled: bool = false
var lp_spooled: bool = false
var intermediate_temp: float = 298.0
var intermediate_pressure: float = 1.0
var base_efficiency: float = 0.82

func _init(system: Node) -> void:
    super._init(system)
    anti_lag_system = null

func update(delta: float):
    var rpm_normalized = turbo_system.get_rpm_normalized()
    update_hp_stage(delta, rpm_normalized)
    update_lp_stage(delta, rpm_normalized)
    current_boost = hp_boost * lp_boost
    calculate_temperatures()
    current_backpressure = 1.0 + (hp_boost - 1.0)*0.5 + (lp_boost - 1.0)*0.3
    calculate_turbo_load_factor(rpm_normalized)
    update_turbo_efficiency(rpm_normalized)
    update_wastegate(delta)  # Controle de wastegate
    apply_intercooler()

func update_hp_stage(delta: float, rpm_norm: float):
    var hp_target = 1.0 + smoothstep(0.0, 0.3, rpm_norm) * turbo_system.intermediate_pressure
    var response_rate = lerp(10.0, 25.0, rpm_norm)
    hp_boost = move_toward(hp_boost, hp_target, response_rate * delta)
    hp_spooled = hp_boost > 1.05 || rpm_norm > 0.2
    intermediate_pressure = hp_boost

func update_lp_stage(delta: float, rpm_norm: float):
    var lp_target = 1.0
    if rpm_norm > 0.4:
        lp_target = 1.0 + smoothstep(0.4, 0.8, rpm_norm) * (turbo_system.max_boost_pressure - 1.0)
    var response_rate = lerp(1.0, 4.0, rpm_norm * intermediate_pressure)
    lp_boost = move_toward(lp_boost, lp_target, response_rate * delta)
    lp_spooled = rpm_norm > 0.5 && hp_spooled

func calculate_temperatures():
    var gamma = 1.4
    var hp_temp_ratio = pow(hp_boost, (gamma - 1.0)/gamma)
    var hp_ideal_temp = turbo_system.AMBIENT_TEMPERATURE * hp_temp_ratio
    intermediate_temp = turbo_system.AMBIENT_TEMPERATURE + (hp_ideal_temp - turbo_system.AMBIENT_TEMPERATURE) / 0.78
    
    if turbo_system.intercooler_installed:
        var reduction = (intermediate_temp - turbo_system.AMBIENT_TEMPERATURE) * turbo_system.intercooler_efficiency
        intermediate_temp = max(turbo_system.AMBIENT_TEMPERATURE, intermediate_temp - reduction)
    
    var lp_temp_ratio = pow(lp_boost, (gamma - 1.0)/gamma)
    var lp_ideal_temp = intermediate_temp * lp_temp_ratio
    var lp_outlet_temp = intermediate_temp + (lp_ideal_temp - intermediate_temp) / 0.80
    
    intake_temperature = lp_outlet_temp

func calculate_turbo_load_factor(rpm_normalized: float):
    var rpm_factor = clamp((turbo_system.engine_rpm - turbo_system.idle_rpm) / (turbo_system.redline_rpm - turbo_system.idle_rpm), 0.0, 1.0)
    var boost_factor = clamp((current_boost - 1.0) / turbo_system.max_boost_pressure, 0.0, 1.0)
    turbo_load_factor = clamp(rpm_factor * boost_factor * 1.5, -0.8, 1.0)

func update_turbo_efficiency(rpm_normalized: float):
    var efficiency = base_efficiency
    
    if turbo_system.turbo_oversized || turbo_system.turbo_undersized:
        efficiency *= 0.9
    
    if turbo_system.turbo_efficiency_curve:
        efficiency *= turbo_system.turbo_efficiency_curve.interpolate(turbo_load_factor)
    else:
        efficiency *= 0.85 + 0.15 * (1.0 - abs(turbo_load_factor))
    
    var temp_reduction = clamp((intake_temperature - turbo_system.AMBIENT_TEMPERATURE) / 120.0, 0.0, 0.3)
    current_efficiency = efficiency * (1.0 - temp_reduction)

func get_data() -> Dictionary:
    var data = super.get_data()
    data["type"] = "Compound Turbo"
    data["hp_boost"] = hp_boost
    data["lp_boost"] = lp_boost
    data["intermediate_pressure"] = intermediate_pressure
    data["intermediate_temp"] = intermediate_temp
    data["hp_spooled"] = hp_spooled
    data["lp_spooled"] = lp_spooled
    data["anti_lag_active"] = false
    return data