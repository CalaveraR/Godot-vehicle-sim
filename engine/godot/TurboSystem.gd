class_name TurboSystem
extends RefCounted

enum InductionType {
    NATURALLY_ASPIRATED = 0,
    SUPERCHARGED = 1,
    TURBOCHARGER = 2,
    TWIN_TURBO = 3,
    TWIN_TURBO_STAGGERED = 4,
    COMPOUND_TURBO = 5,
    ELECTRIC_TURBO = 6,
    TWIN_CHARGED = 7
}

enum VGTMode { FIXED, AUTO_ADJUST }
enum AntiLagMode { OFF, PASSIVE, ACTIVE, RACE_ACTIVE }
enum WastegateType { INTERNAL, EXTERNAL, ELECTRONIC }

const INDUCTION_CLASS_MAP = {
    InductionType.NATURALLY_ASPIRATED: preload("naturally_aspirated_system.gd"),
    InductionType.SUPERCHARGED: preload("supercharger_system.gd"),
    InductionType.TURBOCHARGER: preload("single_turbo_system.gd"),
    InductionType.TWIN_TURBO: preload("twin_turbo_system.gd"),
    InductionType.TWIN_TURBO_STAGGERED: preload("staggered_turbo_system.gd"),
    InductionType.COMPOUND_TURBO: preload("compound_turbo_system.gd"),
    InductionType.ELECTRIC_TURBO: preload("electric_turbo_system.gd"),
    InductionType.TWIN_CHARGED: preload("twin_charged_system.gd")
}

# Sistema de indução atual
var induction_instance: InductionSystem = null
var induction_type: int = InductionType.TURBOCHARGER

# Estado
var engine_rpm: float = 0.0
var engine_throttle: float = 0.0
var engine_displacement: float = 0.0
var engine_cylinders: int = 0
var redline_rpm: float = 7000.0
var idle_rpm: float = 800.0
var max_naturally_aspirated_hp: float = 150.0
var current_boost: float = 1.0
var current_efficiency: float = 1.0
var turbo_surge: bool = false
var current_backpressure: float = 1.0
var exhaust_flow_rate: float = 0.0
var exhaust_temperature: float = 500.0
var compressor_map: Curve2D
var turbine_response_curve: Curve2D
var spool_time_curve: Curve2D

func _init():
    create_induction_system()
    create_default_curves()

func create_default_curves():
    # Curva de eficiência do compressor
    compressor_map = Curve2D.new()
    compressor_map.add_point(Vector2(0.1, 0.65))  # Low flow
    compressor_map.add_point(Vector2(0.3, 0.78))  # Peak efficiency
    compressor_map.add_point(Vector2(0.5, 0.65))  # High flow
    
    # Curva de resposta da turbina
    turbine_response_curve = Curve2D.new()
    turbine_response_curve.add_point(Vector2(0.0, 0.1))   # Low RPM
    turbine_response_curve.add_point(Vector2(0.5, 0.8))   # Mid RPM
    turbine_response_curve.add_point(Vector2(1.0, 0.95))  # Peak RPM
    
    # Tempo de spool por pressão de exaustão
    spool_time_curve = Curve2D.new()
    spool_time_curve.add_point(Vector2(1.0, 2.0))  # Low pressure
    spool_time_curve.add_point(Vector2(2.0, 0.8))  # Medium pressure
    spool_time_curve.add_point(Vector2(3.0, 0.3))  # High pressure

func create_induction_system():
    if induction_instance:
        induction_instance.free()
    
    var induction_class = INDUCTION_CLASS_MAP.get(induction_type, INDUCTION_CLASS_MAP[InductionType.TURBOCHARGER])
    induction_instance = induction_class.new(self)

func update_turbo(delta: float):
    if induction_instance:
        induction_instance.update(delta, engine_rpm, engine_throttle)
        current_boost = induction_instance.get_boost()
        current_efficiency = induction_instance.get_efficiency()
    
    # Atualizar com dados de backpressure se disponível
    if exhaust_flow_rate > 0:
        calculate_turbo_response(delta)

func calculate_turbo_response(delta: float):
    # Cálculo mais realista usando curvas
    var rpm_ratio = engine_rpm / redline_rpm
    var turbine_efficiency = turbine_response_curve.sample(rpm_ratio)
    
    # Fator de spool baseado na pressão de exaustão
    var spool_factor = spool_time_curve.sample(current_backpressure)
    
    # Atualização do boost com inércia
    current_boost = lerp(
        current_boost, 
        current_boost * turbine_efficiency,
        delta * spool_factor
    )
    
    # Aplicar efeito de backpressure na eficiência
    var pressure_ratio = current_backpressure / current_boost
    current_efficiency = compressor_map.sample(pressure_ratio)

func get_current_boost() -> float:
    return current_boost

func get_intake_temp() -> float:
    return induction_instance.get_intake_temp() if induction_instance else EngineConfig.ambient_temp

func update_turbo_inputs(rpm: float, throttle: float, displacement: float, cylinders: int):
    engine_rpm = rpm
    engine_throttle = throttle
    engine_displacement = displacement
    engine_cylinders = cylinders

func set_engine_parameters(redline: float, idle: float, max_na_hp: float):
    redline_rpm = redline
    idle_rpm = idle
    max_naturally_aspirated_hp = max_na_hp

func set_induction_type(type: int):
    induction_type = type
    create_induction_system()

func configure_turbo(turbine_size: float, compressor_size: float, boost_level: float):
    # Configuração básica
    current_boost = boost_level

func set_supercharger_settings(boost_level: float, drive_ratio: float):
    current_boost = boost_level

func configure_twin_charged(supercharger_boost: float, turbo1_size: float, turbo2_size: float, max_boost: float):
    current_boost = supercharger_boost

func get_efficiency() -> float:
    return current_efficiency