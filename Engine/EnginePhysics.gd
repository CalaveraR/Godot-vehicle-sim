class_name EnginePhysics

const HP_TO_TORQUE = 5252.0
const SPECIFIC_HEAT_RATIO = 1.4
const GAS_CONSTANT = 287.0
const ATMOSPHERIC_PRESSURE = 1.01325
const AIR_TEMPERATURE = 298.0

static func calculate_engine_output(
    torque_base_curve: Curve,
    throttle_position: float,
    turbo_data: Dictionary,
    cyl_head_data: Dictionary,
    rpm: float,
    induction_type: int,
    vibration_level: float,
    cylinder_count: int,
    max_hp: float,
    redline_rpm: float,
    max_vvt_advance: float
) -> Dictionary:
    
    var rpm_normalized = rpm / redline_rpm
    var torque_fraction = torque_base_curve.interpolate(rpm_normalized)
    var peak_torque = (max_hp * HP_TO_TORQUE) / EngineConfig.peak_torque_rpm
    var base_torque = torque_fraction * peak_torque
    
    var air_density = calculate_air_density(turbo_data["boost"])
    var ve = cyl_head_data["volumetric_efficiency"]
    
    var current_torque = base_torque * air_density * ve * turbo_data["efficiency"] * throttle_position
    
    var vvt_torque_factor = 1.0 + (cyl_head_data["vvt_advance"] / max_vvt_advance) * 0.1
    current_torque *= clamp(vvt_torque_factor, 0.9, 1.1)
    
    if induction_type == TurboSystem.InductionType.SUPERCHARGED:
        var supercharger_drag = base_torque * 0.15 * (turbo_data["boost"] - 1.0)
        current_torque = max(current_torque - supercharger_drag, base_torque * 0.7)
    
    var vibration_loss = 1.0 - vibration_level * 0.1
    current_torque *= clamp(vibration_loss, 0.8, 1.0)
    
    var torque_smoothness = 1.0
    if cylinder_count >= 6:
        torque_smoothness = 1.05
    current_torque *= torque_smoothness
    
    var current_horsepower = (current_torque * rpm) / HP_TO_TORQUE
    current_horsepower = min(current_horsepower, max_hp)
    
    if abs(rpm - HP_TO_TORQUE) < 100:
        var ratio = rpm / HP_TO_TORQUE
        current_horsepower = current_torque * ratio

    return {
        "torque": current_torque,
        "horsepower": current_horsepower
    }

static func calculate_air_density(boost_pressure: float) -> float:
    var pressure_ratio = boost_pressure
    var temperature_ratio = pow(pressure_ratio, (SPECIFIC_HEAT_RATIO - 1.0) / SPECIFIC_HEAT_RATIO)
    var outlet_temp = AIR_TEMPERATURE * temperature_ratio
    var compressor_efficiency = 0.75
    var ideal_temp_rise = outlet_temp - AIR_TEMPERATURE
    var actual_temp_rise = ideal_temp_rise / compressor_efficiency
    var actual_outlet_temp = AIR_TEMPERATURE + actual_temp_rise
    var absolute_pressure = ATMOSPHERIC_PRESSURE * pressure_ratio * 100000
    var air_density = absolute_pressure / (GAS_CONSTANT * actual_outlet_temp)
    var atmospheric_density = ATMOSPHERIC_PRESSURE * 100000 / (GAS_CONSTANT * AIR_TEMPERATURE)
    return air_density / atmospheric_density

static func apply_backpressure_effects(
    backpressure: float, 
    air_flow: float,
    cylinder_head: CylinderHead,
    turbo_system: TurboSystem,
    throttle: float,
    scavenging_factor: float
):
    if not cylinder_head:
        return
    
    # Efeito negativo do backpressure
    var ve_reduction = clamp((backpressure - 1.0) * 0.12, 0.0, 0.35)
    
    # Efeito positivo do scavenging (apenas em aspirados)
    var scavenging_boost = 0.0
    if not turbo_system:
        scavenging_boost = scavenging_factor * 0.25
    
    # Aplicar ambos efeitos
    cylinder_head.volumetric_efficiency = cylinder_head.volumetric_efficiency * (1.0 - ve_reduction) + scavenging_boost
    
    # Efeito no fluxo de ar
    var flow_reduction = clamp((backpressure - 1.0) * 0.08, 0.0, 0.25)
    air_flow *= (1.0 - flow_reduction)
    
    # Efeito no turbo
    if turbo_system:
        # Turbo surge detection
        if backpressure > turbo_system.current_boost * 2.8 and throttle < 0.25:
            turbo_system.turbo_surge = true
            turbo_system.current_boost *= 0.85
        
        # Turbo efficiency penalty
        var efficiency_penalty = clamp((backpressure - 1.5) * 0.15, 0.0, 0.3)
        turbo_system.current_efficiency *= (1.0 - efficiency_penalty)