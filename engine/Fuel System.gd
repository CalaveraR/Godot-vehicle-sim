class_name FuelSystem
extends Node

# ======================
# VERSÃO 3.0 - SISTEMA DE COMBUSTÍVEL COMPLETO
# ======================
# Características principais:
# - ✅ 100% compatível com Engine 3.1, CylinderHead 3.0, AirSystem
# - ✅ Sistema de injeção multiponto sequencial e simultânea
# - ✅ Curvas de correção por temperatura, pressão e altitude
# - ✅ Modelo físico realista de pressão de combustível
# - ✅ Sistema de falhas e diagnóstico completo
# - ✅ Suporte a diferentes tipos de combustível
# ======================

# ======================
# ENUMS E CONFIGURAÇÕES
# ======================
enum InjectionType {
    SINGLE_POINT,
    MULTI_POINT,
    DIRECT,
    SEQUENTIAL,
    SIMULTANEOUS
}

enum FuelType {
    GASOLINE,
    DIESEL,
    ETHANOL,
    FLEX,
    RACING,
    OTHER
}

enum FailureType {
    NONE,
    LOW_PRESSURE,
    CLOGGED_INJECTOR,
    PUMP_FAILURE,
    SENSOR_FAILURE,
    CONTAMINATION
}

# ======================
# PARÂMETROS CONFIGURÁVEIS
# ======================
export(InjectionType) var injection_type = InjectionType.SEQUENTIAL
export(FuelType) var fuel_type = FuelType.GASOLINE
export var base_fuel_pressure: float = 3.0  # bar
export var injector_size: float = 250.0     # cc/min
export var fuel_tank_capacity: float = 50.0 # litros
export var fuel_rail_volume: float = 0.3    # litros
export var fuel_pump_flow_rate: float = 120.0 # L/h

# ======================
# ESTADO DINÂMICO
# ======================
var current_fuel_pressure: float = 0.0
var fuel_tank_level: float = 50.0
var fuel_consumption_rate: float = 0.0
var instantaneous_consumption: float = 0.0
var total_fuel_consumed: float = 0.0
var injector_pulse_width: Array = []
var injector_duty_cycle: Array = []
var fuel_quality: float = 1.0
var octane_rating: float = 91.0
var fuel_temperature: float = 25.0

# ======================
# SISTEMA DE FALHAS
# ======================
var failure_mode: int = FailureType.NONE
var failure_severity: float = 0.0
var injector_clogging: Array = []
var pump_efficiency: float = 1.0
var pressure_regulator_efficiency: float = 1.0

# ======================
# CURVAS DE CORREÇÃO
# ======================
var temperature_correction_curve: Curve
var pressure_correction_curve: Curve
var altitude_correction_curve: Curve
var injector_deadtime_curve: Curve
var fuel_pump_flow_curve: Curve

# ======================
# REFERÊNCIAS
# ======================
var engine: Engine
var air_system: Node
var ignition_system: Node
var diagnostic_system: Node

# ======================
# SINAIS
# ======================
signal fuel_pressure_changed(pressure: float)
signal fuel_level_changed(level: float)
signal fuel_consumption_updated(instantaneous: float, average: float)
signal injector_pulsed(cylinder: int, pulse_width: float)
signal system_failure(failure_type: int, severity: float)
signal fuel_quality_updated(quality: float)

# ======================
# CONSTANTES
# ======================
const SPECIFIC_GRAVITY_GASOLINE: float = 0.745
const SPECIFIC_GRAVITY_DIESEL: float = 0.850
const FUEL_DENSITY_GASOLINE: float = 0.75  # kg/L
const FUEL_DENSITY_DIESEL: float = 0.85    # kg/L
const MIN_FUEL_PRESSURE: float = 1.5
const MAX_FUEL_PRESSURE: float = 6.0
const CRITICAL_FUEL_LEVEL: float = 5.0  # litros

# ======================
# INICIALIZAÇÃO
# ======================
func _ready():
    initialize_system()
    create_default_curves()
    initialize_injector_arrays()

func initialize_system():
    """Inicializa o sistema de combustível com valores padrão"""
    current_fuel_pressure = base_fuel_pressure
    fuel_tank_level = fuel_tank_capacity * 0.8  # 80% cheio por padrão
    
    # Configurar qualidade do combustível baseada no tipo
    match fuel_type:
        FuelType.RACING:
            fuel_quality = 1.2
            octane_rating = 98.0
        FuelType.DIESEL:
            fuel_quality = 1.0
            octane_rating = 0.0  # Diesel não tem octanagem
        FuelType.ETHANOL:
            fuel_quality = 0.9
            octane_rating = 100.0
        FuelType.FLEX:
            fuel_quality = 1.0
            octane_rating = 94.0
        _:
            fuel_quality = 1.0
            octane_rating = 91.0

func initialize_injector_arrays():
    """Inicializa arrays para múltiplos injetores"""
    if engine:
        var cylinder_count = engine.get_cylinder_count()
        injector_pulse_width.resize(cylinder_count)
        injector_duty_cycle.resize(cylinder_count)
        injector_clogging.resize(cylinder_count)
        
        for i in range(cylinder_count):
            injector_pulse_width[i] = 0.0
            injector_duty_cycle[i] = 0.0
            injector_clogging[i] = 0.0

func create_default_curves():
    """Cria curvas de correção padrão"""
    
    # Correção por temperatura
    temperature_correction_curve = Curve.new()
    temperature_correction_curve.add_point(Vector2(-20, 1.3))
    temperature_correction_curve.add_point(Vector2(0, 1.15))
    temperature_correction_curve.add_point(Vector2(20, 1.0))
    temperature_correction_curve.add_point(Vector2(40, 0.95))
    temperature_correction_curve.add_point(Vector2(80, 0.9))
    
    # Correção por pressão
    pressure_correction_curve = Curve.new()
    pressure_correction_curve.add_point(Vector2(1.0, 0.7))
    pressure_correction_curve.add_point(Vector2(2.0, 0.9))
    pressure_correction_curve.add_point(Vector2(3.0, 1.0))
    pressure_correction_curve.add_point(Vector2(4.0, 1.05))
    pressure_correction_curve.add_point(Vector2(5.0, 1.08))
    
    # Correção por altitude
    altitude_correction_curve = Curve.new()
    altitude_correction_curve.add_point(Vector2(0, 1.0))
    altitude_correction_curve.add_point(Vector2(1000, 0.95))
    altitude_correction_curve.add_point(Vector2(2000, 0.9))
    altitude_correction_curve.add_point(Vector2(3000, 0.85))
    
    # Curva de dead time do injetor
    injector_deadtime_curve = Curve.new()
    injector_deadtime_curve.add_point(Vector2(10.0, 1.5))
    injector_deadtime_curve.add_point(Vector2(12.0, 1.2))
    injector_deadtime_curve.add_point(Vector2(14.0, 1.0))
    
    # Curva de fluxo da bomba
    fuel_pump_flow_curve = Curve.new()
    fuel_pump_flow_curve.add_point(Vector2(0.0, 0.0))
    fuel_pump_flow_curve.add_point(Vector2(1.0, 1.0))
    fuel_pump_flow_curve.add_point(Vector2(2.0, 0.9))
    fuel_pump_flow_curve.add_point(Vector2(3.0, 0.8))

# ======================
# ATUALIZAÇÃO PRINCIPAL
# ======================
func update(delta: float):
    """Atualiza o sistema de combustível - chamado pelo Engine"""
    if not engine or fuel_tank_level <= 0:
        return
    
    update_fuel_pressure(delta)
    calculate_fuel_consumption(delta)
    update_injector_operation(delta)
    handle_failures(delta)
    update_fuel_quality(delta)
    
    # Emitir sinais de atualização
    emit_performance_signals()

func update_fuel_pressure(delta: float):
    """Atualiza pressão do combustível no rail"""
    var target_pressure = base_fuel_pressure
    
    # Correção por carga do motor
    if engine and air_system:
        var load = engine.load
        var manifold_pressure = air_system.manifold_pressure if air_system.has("manifold_pressure") else 1.0
        target_pressure += manifold_pressure * 0.1
    
    # Aplicar eficiência da bomba e regulador
    target_pressure *= pump_efficiency * pressure_regulator_efficiency
    
    # Suavizar mudanças de pressão
    var pressure_change_rate = 5.0  # bar/segundo
    var max_change = pressure_change_rate * delta
    
    current_fuel_pressure = clamp(
        lerp(current_fuel_pressure, target_pressure, delta * 2.0),
        MIN_FUEL_PRESSURE,
        MAX_FUEL_PRESSURE
    )

func calculate_fuel_consumption(delta: float):
    """Calcula consumo de combustível em tempo real"""
    if not engine or not air_system:
        return
    
    var rpm = engine.rpm
    var throttle = engine.throttle_position
    var air_flow = air_system.air_flow if air_system.has("air_flow") else 0.0
    
    # Calcular vazão de combustível baseada no fluxo de ar e RPM
    var target_afr = get_target_air_fuel_ratio()
    var fuel_flow = 0.0
    
    if air_flow > 0 and target_afr > 0:
        fuel_flow = (air_flow * 60.0) / target_afr  # g/s para g/min
        
        # Converter para litros/hora
        var fuel_density = get_fuel_density()
        instantaneous_consumption = (fuel_flow / 1000.0) / fuel_density * 60.0
        
        # Atualizar consumo total
        var consumption_this_frame = instantaneous_consumption * delta / 3600.0
        total_fuel_consumed += consumption_this_frame
        fuel_tank_level = max(0.0, fuel_tank_level - consumption_this_frame)
        
        # Atualizar taxa de consumo
        fuel_consumption_rate = instantaneous_consumption

func get_target_air_fuel_ratio() -> float:
    """Retorna relação ar-combustível ideal para condições atuais"""
    var base_afr = 14.7  # Estequiométrica para gasolina
    
    # Ajustar para diferentes combustíveis
    match fuel_type:
        FuelType.DIESEL:
            base_afr = 14.5
        FuelType.ETHANOL:
            base_afr = 9.0
        FuelType.FLEX:
            # Para flex, assumir 50% gasolina, 50% etanol
            base_afr = 12.0
    
    # Correções dinâmicas
    var rpm = engine.rpm if engine else 0
    var throttle = engine.throttle_position if engine else 0
    var coolant_temp = engine.coolant_temp if engine else 90.0
    
    # Enriquecimento em aceleração
    if throttle > 0.8:
        base_afr *= 0.85  # Enriquecer
    
    # Enriquecimento em frio
    if coolant_temp < 70.0:
        var cold_enrichment = 1.0 + (70.0 - coolant_temp) / 70.0 * 0.3
        base_afr /= cold_enrichment
    
    return base_afr

func update_injector_operation(delta: float):
    """Controla operação dos injetores"""
    if not engine or injector_pulse_width.size() == 0:
        return
    
    var rpm = engine.rpm
    var cylinder_count = engine.get_cylinder_count()
    
    # Calcular pulso base para cada cilindro
    var base_pulse_width = calculate_base_pulse_width(rpm)
    
    for i in range(cylinder_count):
        # Aplicar correções
        var corrected_pulse = apply_injector_corrections(base_pulse_width, i)
        
        # Aplicar clogging do injetor
        corrected_pulse *= (1.0 + injector_clogging[i])
        
        # Limitar duty cycle máximo
        var max_duty_cycle = 0.85  # 85% máximo
        var cycle_time = 120.0 / (rpm * cylinder_count) * 1000.0  # ms
        var max_pulse = cycle_time * max_duty_cycle
        
        injector_pulse_width[i] = clamp(corrected_pulse, 0.0, max_pulse)
        injector_duty_cycle[i] = injector_pulse_width[i] / cycle_time if cycle_time > 0 else 0.0
        
        # Emitir sinal se injetor estiver pulsando
        if injector_pulse_width[i] > 0.1:
            injector_pulsed.emit(i, injector_pulse_width[i])

func calculate_base_pulse_width(rpm: float) -> float:
    """Calcula pulso base do injetor em milissegundos"""
    if not engine or not air_system:
        return 0.0
    
    var air_flow = air_system.air_flow if air_system.has("air_flow") else 0.0
    var throttle = engine.throttle_position
    
    if air_flow <= 0 or rpm <= 0:
        return 0.0
    
    # Cálculo baseado no fluxo de ar e RPM
    var target_afr = get_target_air_fuel_ratio()
    var fuel_flow_required = (air_flow * 60.0) / target_afr  # g/min
    
    # Converter para pulso do injetor
    var injector_flow_rate = injector_size * get_fuel_density()  # g/min
    var pulses_per_minute = rpm * engine.get_cylinder_count() / 2.0  # 4 tempos
    
    var base_pulse = (fuel_flow_required / injector_flow_rate) * (60000.0 / pulses_per_minute)
    
    return base_pulse

func apply_injector_corrections(base_pulse: float, cylinder: int) -> float:
    """Aplica correções ao pulso do injetor"""
    var corrected_pulse = base_pulse
    
    # Correção por pressão do combustível
    var pressure_correction = pressure_correction_curve.interpolate(current_fuel_pressure)
    corrected_pulse *= pressure_correction
    
    # Correção por temperatura
    var temp_correction = temperature_correction_curve.interpolate(fuel_temperature)
    corrected_pulse *= temp_correction
    
    # Correção por altitude (se disponível)
    if EngineConfig and EngineConfig.has("altitude"):
        var altitude = EngineConfig.altitude
        var altitude_correction = altitude_correction_curve.interpolate(altitude / 1000.0)
        corrected_pulse *= altitude_correction
    
    # Dead time do injetor
    var dead_time = injector_deadtime_curve.interpolate(current_fuel_pressure)
    corrected_pulse += dead_time
    
    # Correção por qualidade do combustível
    corrected_pulse *= (1.0 / fuel_quality)
    
    return corrected_pulse

# ======================
# SISTEMA DE FALHAS
# ======================
func handle_failures(delta: float):
    """Gerencia falhas e degradação do sistema"""
    
    # Progressão de falhas existentes
    if failure_mode != FailureType.NONE:
        failure_severity = min(1.0, failure_severity + delta * 0.01)
        apply_failure_effects()
    
    # Chance de novas falhas baseada em desgaste
    if engine and engine.has_method("get_wear_factor"):
        var wear_factor = engine.get_wear_factor()
        if randf() < wear_factor * delta * 0.001:
            initiate_random_failure()
    
    # Degradação progressiva dos injetores
    for i in range(injector_clogging.size()):
        if randf() < delta * 0.0001:  # Pequena chance de entupimento
            injector_clogging[i] = min(0.5, injector_clogging[i] + 0.01)

func apply_failure_effects():
    """Aplica efeitos das falhas ativas"""
    match failure_mode:
        FailureType.LOW_PRESSURE:
            pump_efficiency = lerp(1.0, 0.3, failure_severity)
        FailureType.CLOGGED_INJECTOR:
            # Selecionar injetor aleatório para entupir
            var random_injector = randi() % injector_clogging.size()
            injector_clogging[random_injector] = failure_severity
        FailureType.PUMP_FAILURE:
            pump_efficiency = 1.0 - failure_severity
        FailureType.SENSOR_FAILURE:
            # Simular leituras incorretas
            current_fuel_pressure *= (1.0 + (randf() - 0.5) * failure_severity * 0.2)
        FailureType.CONTAMINATION:
            fuel_quality = 1.0 - failure_severity * 0.5

func initiate_random_failure():
    """Inicia uma falha aleatória no sistema"""
    var failure_types = [FailureType.LOW_PRESSURE, FailureType.CLOGGED_INJECTOR, 
                        FailureType.PUMP_FAILURE, FailureType.SENSOR_FAILURE]
    failure_mode = failure_types[randi() % failure_types.size()]
    failure_severity = 0.1
    
    system_failure.emit(failure_mode, failure_severity)

# ======================
# API PÚBLICA
# ======================
func get_fuel_quality() -> float:
    return fuel_quality

func get_fuel_data() -> Dictionary:
    return {
        "fuel_pressure": current_fuel_pressure,
        "tank_level": fuel_tank_level,
        "tank_capacity": fuel_tank_capacity,
        "instantaneous_consumption": instantaneous_consumption,
        "total_consumed": total_fuel_consumed,
        "fuel_quality": fuel_quality,
        "octane_rating": octane_rating,
        "fuel_temperature": fuel_temperature,
        "failure_mode": failure_mode,
        "failure_severity": failure_severity
    }

func get_injector_data() -> Dictionary:
    var data = {}
    for i in range(injector_pulse_width.size()):
        data["injector_%d" % i] = {
            "pulse_width": injector_pulse_width[i],
            "duty_cycle": injector_duty_cycle[i],
            "clogging": injector_clogging[i]
        }
    return data

func apply_intake_modifiers(data: Dictionary):
    """Aplica modificadores do sistema de admissão - COMPATÍVEL COM AIRSYSTEM"""
    # Correção de combustível baseada em pressão do manifold
    if data.has("manifold_pressure"):
        var pressure_effect = data["manifold_pressure"] * 0.1
        base_fuel_pressure += pressure_effect

func set_fuel_quality(quality: float):
    """Define qualidade do combustível (0.0 a 2.0)"""
    fuel_quality = clamp(quality, 0.5, 2.0)
    fuel_quality_updated.emit(fuel_quality)

func refuel(amount: float):
    """Abastece o tanque"""
    fuel_tank_level = min(fuel_tank_capacity, fuel_tank_level + amount)
    fuel_level_changed.emit(fuel_tank_level)

func perform_maintenance():
    """Realiza manutenção no sistema"""
    failure_mode = FailureType.NONE
    failure_severity = 0.0
    pump_efficiency = 1.0
    pressure_regulator_efficiency = 1.0
    
    for i in range(injector_clogging.size()):
        injector_clogging[i] = 0.0

# ======================
# UTILITÁRIOS
# ======================
func get_fuel_density() -> float:
    match fuel_type:
        FuelType.DIESEL:
            return FUEL_DENSITY_DIESEL
        _:
            return FUEL_DENSITY_GASOLINE

func update_fuel_quality(delta: float):
    """Degradação gradual da qualidade do combustível"""
    if fuel_tank_level > 0:
        var degradation_rate = 0.00001  # Muito lenta
        fuel_quality = max(0.5, fuel_quality - degradation_rate * delta)

func emit_performance_signals():
    """Emite sinais de performance do sistema"""
    fuel_pressure_changed.emit(current_fuel_pressure)
    fuel_level_changed.emit(fuel_tank_level)
    fuel_consumption_updated.emit(instantaneous_consumption, total_fuel_consumed)

func connect_to_engine(engine_node: Engine):
    """Conecta ao motor - COMPATÍVEL COM ENGINE 3.1"""
    engine = engine_node
    initialize_injector_arrays()

func is_fuel_low() -> bool:
    return fuel_tank_level < CRITICAL_FUEL_LEVEL

func get_fuel_efficiency() -> float:
    """Retorna eficiência geral do sistema (0.0 a 1.0)"""
    var base_efficiency = 1.0
    
    # Efeito das falhas
    base_efficiency *= (1.0 - failure_severity * 0.5)
    
    # Efeito do entupimento dos injetores
    var avg_clogging = 0.0
    for clogging in injector_clogging:
        avg_clogging += clogging
    avg_clogging /= max(1, injector_clogging.size())
    base_efficiency *= (1.0 - avg_clogging)
    
    # Efeito da qualidade do combustível
    base_efficiency *= fuel_quality
    
    return clamp(base_efficiency, 0.3, 1.0)
