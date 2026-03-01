class_name OilSystem
extends Node

# ======================
# VERSÃO 3.1 - SISTEMA DE ÓLEO COMPATÍVEL
# ======================
# Melhorias:
# ======================

# Constantes
const SPECIFIC_HEAT_OIL: float = 1.9
const OIL_DENSITY_BASE: float = 0.85
const MAX_SAFE_TEMP: float = 150.0
const MIN_SAFE_TEMP: float = -20.0

# Configuração (COMPATÍVEL)
var oil_capacity: float = 5.0
var oil_viscosity_index: float = 160
var oil_pump_capacity: float = 20.0
var oil_cooler_efficiency: float = 0.7

# Estado (COMPATÍVEL)
var oil_temperature: float = 90.0
var oil_pressure: float = 3.0
var oil_flow_rate: float = 0.0
var oil_heat_loss: float = 0.0
var oil_viscosity: float = 14.0
var oil_quality: float = 1.0

# Curvas (✅ OTIMIZADO: Curve em vez de Curve2D)
var viscosity_temp_curve: Curve
var pump_efficiency_curve: Curve
var pressure_relief_curve: Curve

# Referências (COMPATÍVEL)
var engine: Engine

func _ready():
    initialize_system()

func initialize_system():
    """✅ COMPATÍVEL: Inicialização do sistema"""
    oil_temperature = EngineConfig.ambient_temp + 10.0
    create_default_curves()

func create_default_curves():
    """✅ OTIMIZADO: Curvas padrão com Curve"""
    
    # Curva de viscosidade vs temperatura
    viscosity_temp_curve = Curve.new()
    viscosity_temp_curve.add_point(Vector2(40, 65))
    viscosity_temp_curve.add_point(Vector2(60, 25))
    viscosity_temp_curve.add_point(Vector2(80, 15))
    viscosity_temp_curve.add_point(Vector2(100, 12))
    viscosity_temp_curve.add_point(Vector2(120, 8))
    viscosity_temp_curve.add_point(Vector2(140, 5))
    
    # Curva de eficiência da bomba
    pump_efficiency_curve = Curve.new()
    pump_efficiency_curve.add_point(Vector2(0.0, 0.3))
    pump_efficiency_curve.add_point(Vector2(0.4, 0.8))
    pump_efficiency_curve.add_point(Vector2(0.8, 0.9))
    pump_efficiency_curve.add_point(Vector2(1.0, 0.85))
    pump_efficiency_curve.add_point(Vector2(1.2, 0.75))

# ======================
# MÉTODOS PRINCIPAIS (COMPATÍVEIS)
# ======================

func update(delta: float, rpm: float, coolant_temp: float, vibration_level: float):
    """✅ COMPATÍVEL: Interface exigida pelo Engine 3.1"""
    if not engine:
        return
    
    # Calcular fluxo de óleo
    oil_flow_rate = oil_pump_capacity * (rpm / engine.redline_rpm)
    
    # Calcular viscosidade
    calculate_viscosity()
    
    # Calcular pressão
    oil_pressure = 1.0 + (oil_flow_rate * oil_viscosity * 0.01) * (rpm / 3000.0)
    
    # Calcular temperatura
    calculate_temperature(delta, coolant_temp, vibration_level)
    
    # Calcular perdas por calor
    calculate_heat_loss(rpm)

func calculate_viscosity():
    """✅ COMPATÍVEL: Cálculo de viscosidade"""
    var reference_viscosity = 14.0
    var viscosity_index = oil_viscosity_index
    
    var temp_factor = clamp((oil_temperature - 100.0) / 50.0, -1.0, 2.0)
    oil_viscosity = reference_viscosity * pow(10, viscosity_index * (1.0 - temp_factor) * 0.0001)

func calculate_temperature(delta: float, coolant_temp: float, vibration_level: float):
    """✅ COMPATÍVEL: Cálculo de temperatura"""
    var friction_heat = vibration_level * 5.0
    var combustion_heat = engine.combustion_system.average_combustion_temp * 0.001
    
    var heat_gain = (friction_heat + combustion_heat) * delta
    var cooling_capacity = oil_cooler_efficiency * (oil_temperature - coolant_temp) * oil_flow_rate * 0.1
    
    oil_temperature += heat_gain - cooling_capacity * delta
    oil_temperature = clamp(oil_temperature, 70.0, 150.0)

# ======================
# API PÚBLICA (COMPATÍVEL)
# ======================

func get_efficiency_loss() -> float:
    """✅ COMPATÍVEL: Método exigido pelo Engine 3.1"""
    var temp_loss = clamp(abs(oil_temperature - 100.0) / 40.0, 0.0, 0.4)
    var viscosity_loss = clamp(abs(oil_viscosity - 12.0) / 12.0, 0.0, 0.3)
    var pressure_loss = 0.2 if (oil_pressure < 1.5 or oil_pressure > 5.5) else 0.0
    var quality_loss = (1.0 - oil_quality) * 0.5
    
    var total_loss = (temp_loss + viscosity_loss + pressure_loss + quality_loss) / 4.0
    return clamp(total_loss, 0.0, 0.8)

func get_oil_data() -> Dictionary:
    """✅ COMPATÍVEL: Para Engine.get_oil_system_data()"""
    return {
        "temperature": oil_temperature,
        "pressure": oil_pressure,
        "viscosity": oil_viscosity,
        "flow_rate": oil_flow_rate,
        "quality": oil_quality,
        "efficiency_loss": get_efficiency_loss()
    }

func connect_to_engine(engine_node: Engine):
    """✅ COMPATÍVEL: Para Engine conectar referência"""
    engine = engine_node

func calculate_heat_loss(rpm: float):
    """✅ COMPATÍVEL: Cálculo de perdas térmicas"""
    var pump_power = oil_flow_rate * oil_pressure * 0.01
    var viscous_loss = oil_viscosity * rpm * 0.0001
    oil_heat_loss = pump_power + viscous_loss

# ======================
# SISTEMA DE SINAIS (COMPATÍVEL)
# ======================

signal oil_efficiency_updated(efficiency_loss: float)

func _emit_efficiency_signal():
    """✅ COMPATÍVEL: Emitir sinal de eficiência"""
    oil_efficiency_updated.emit(get_efficiency_loss())
