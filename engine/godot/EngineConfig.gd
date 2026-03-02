class_name EngineConfig

enum EngineType {
    PISTON_4T,  # 4 tempos (padrão)
    PISTON_2T,  # 2 tempos
    WANKEL,     # Rotativo Wankel
    DIESEL      # Diesel
}

enum FuelType {
    GASOLINE,
    DIESEL,
    ETHANOL,
    FLEX,
    OTHER
}

# Parâmetros fundamentais
static var engine_type: int = EngineType.PISTON_4T
static var fuel_type: int = FuelType.GASOLINE
static var displacement: float = 2.0  # Litros
static var chambers: int = 4          # Cilindros ou rotores

# Características específicas
static var compression_ratio: float = 10.0
static var stroke_ratio: float = 1.0
static var rotor_eccentricity: float = 15.0
static var two_stroke_scavenging: float = 0.8

# Configurações de RPM
static var idle_rpm: float = 800.0
static var redline_rpm: float = 7000.0
static var max_rpm: float = 7500.0

# Parâmetros de ar e ambiente
static var ambient_temp: float = 25.0
static var atmospheric_pressure: float = 1.01325  # bar

# Desempenho
static var max_naturally_aspirated_hp: float = 150.0
static var peak_torque_rpm: float = 4000.0
static var max_hp: float = 150.0

# Curvas e parâmetros usados por subsistemas
static var torque_curve: Curve = null
static var vvt_curve: Curve = null
static var ve_curve: Curve = null
static var max_vvt_advance: float = 40.0

# Configurações de exaustão e headers (BackpressureSystem)
static var exhaust_diameter: float = 0.05
static var exhaust_length: float = 2.0
static var exhaust_roughness: float = 0.0001
static var has_catalytic_converter: bool = true
static var muffler_type: int = 0
static var header_type: int = 0
static var header_primary_length: float = 1.5
static var header_primary_diameter: float = 0.045
static var header_secondary_length: float = 0.0
static var header_collector_diameter: float = 0.055

# Inicialização padrão das curvas (chamada quando o script é carregado)
static func _init():
    if torque_curve == null:
        torque_curve = _create_default_torque_curve()
    if vvt_curve == null:
        vvt_curve = _create_default_vvt_curve()
    if ve_curve == null:
        ve_curve = _create_default_ve_curve()

# Curvas padrão
static func _create_default_torque_curve() -> Curve:
    var c = Curve.new()
    c.add_point(Vector2(0.0, 0.6))
    c.add_point(Vector2(0.5, 1.0))   # Pico em ~50% do redline
    c.add_point(Vector2(1.0, 0.85))  # Queda próximo da redline
    return c

static func _create_default_vvt_curve() -> Curve:
    var c = Curve.new()
    c.add_point(Vector2(0.0, 0.0))
    c.add_point(Vector2(1.0, 1.0))
    return c

static func _create_default_ve_curve() -> Curve:
    var c = Curve.new()
    c.add_point(Vector2(0.0, 0.75))
    c.add_point(Vector2(0.4, 0.95))
    c.add_point(Vector2(1.0, 0.85))
    return c

# Método para configurar o motor
static func configure_engine(type: int, chambers: int, displacement: float):
    engine_type = type
    chambers = chambers
    displacement = displacement
    
    # Valores padrão baseados no tipo
    match type:
        EngineType.PISTON_2T:
            compression_ratio = 9.0
            idle_rpm = 1000.0
            redline_rpm = 9000.0
            max_rpm = 9500.0
        EngineType.WANKEL:
            compression_ratio = 9.5
            displacement = chambers * 0.65 * 2
            idle_rpm = 900.0
            redline_rpm = 8500.0
            max_rpm = 9000.0
        EngineType.DIESEL:
            compression_ratio = 18.0
            idle_rpm = 700.0
            redline_rpm = 5000.0
            max_rpm = 5500.0
        _:  # PISTON_4T
            compression_ratio = 10.5
            idle_rpm = 800.0
            redline_rpm = 7000.0
            max_rpm = 7500.0

# Funções de utilidade
static func get_rpm_normalized(rpm: float) -> float:
    return clamp((rpm - idle_rpm) / (redline_rpm - idle_rpm), 0.0, 1.2)
