class_name TwinTurboSystem
extends SingleTurboSystem

func calculate_boost_target(rpm_normalized: float):
    if turbo_system.boost_curve:
        boost_target = turbo_system.boost_curve.interpolate(rpm_normalized)
    else:
        var boost_factor = smoothstep(0.2, 0.6, rpm_normalized)
        boost_target = 1.0 + turbo_system.max_boost_pressure * boost_factor * 1.2
    
    boost_target = lerp(1.0, boost_target, turbo_system.engine_throttle)
    boost_target = min(boost_target, 1.0 + turbo_system.max_boost_pressure)

func apply_turbo_lag(delta: float, rpm_normalized: float):
    if turbo_system.spool_response_curve:
        turbo_response_rate = turbo_system.spool_response_curve.interpolate(rpm_normalized) * 1.3
    else:
        turbo_response_rate = lerp(0.7, 2.5, rpm_normalized)
    
    turbo_spooled = turbo_system.engine_rpm > turbo_system.calculate_spool_rpm() * 0.8
    
    var boost_difference = boost_target - current_boost
    var response = turbo_response_rate * delta
    
    if boost_difference > 0:
        current_boost += min(boost_difference, response)
    else:
        current_boost += max(boost_difference, -response * 1.8)
    
    current_boost = max(current_boost, 1.0)

func get_data() -> Dictionary:
    var data = super.get_data()
    data["type"] = "Twin Turbo"
    return data