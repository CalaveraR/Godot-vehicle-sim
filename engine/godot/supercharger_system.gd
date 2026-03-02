class_name SuperchargerSystem
extends InductionSystem

func update(delta: float):
    var rpm_normalized = turbo_system.get_rpm_normalized()
    current_boost = 1.0 + rpm_normalized * turbo_system.max_boost_pressure * turbo_system.supercharger_ratio
    turbo_spooled = true
    
    if turbo_system.turbo_efficiency_curve:
        var load_factor = (current_boost - 1.0) / turbo_system.max_boost_pressure
        current_efficiency = turbo_system.turbo_efficiency_curve.interpolate(load_factor)
    else:
        current_efficiency = 0.85 - (rpm_normalized * 0.05)
    
    current_backpressure = 1.0 + (current_boost - 1.0) * 0.4
    turbo_load_factor = rpm_normalized * turbo_system.engine_throttle
    supercharger_drag = turbo_system.engine_rpm * turbo_system.engine_rpm * 0.00015 * turbo_system.supercharger_ratio
    turbo_surge = false
    intake_temperature = turbo_system.AMBIENT_TEMPERATURE + (current_boost - 1.0) * 20.0
    apply_intercooler()

func get_data() -> Dictionary:
    var data = super.get_data()
    data["type"] = "Supercharger"
    return data