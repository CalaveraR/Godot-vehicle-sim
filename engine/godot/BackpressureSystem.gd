class_name BackpressureSystem
extends Node

enum EngineType {NATURALLY_ASPIRATED, FORCED_INDUCTION}
enum HeaderType {
    LOG_MANIFOLD,      # Coletor tipo "tronco" (stock)
    SHORT_TUBE,        # Tubos curtos (performance básica)
    LONG_TUBE,         # Tubos longos (torque baixo-médio)
    EQUAL_LENGTH,      # Tubos igualitários (performance alta)
    TRI_Y,             # 4-2-1 (balanceado)
    EXOTIC_TUNED       # Projetado específico para motor
}

# Configuração
var exhaust_diameter: float = 0.05  # metros (50mm)
var exhaust_length: float = 2.0     # metros
var exhaust_material_roughness: float = 0.0001  # rugosidade relativa (aço)
var has_catalytic_converter: bool = true
var muffler_type: int = 0  # 0 = esportivo, 1 = padrão, 2 = silencioso
var turbo_backpressure_factor: float = 1.8

# Configuração de headers
var header_type: int = HeaderType.LOG_MANIFOLD
var header_primary_length: float = 1.5
var header_primary_diameter: float = 0.045
var header_secondary_length: float = 0.0
var header_collector_diameter: float = 0.055
var header_material_roughness: float = 0.00005

# Curvas de performance
var muffler_restriction_curve: Curve2D
var cat_restriction_curve: Curve2D
var temperature_density_curve: Curve2D
var rpm_flow_curve: Curve2D
var scavenging_efficiency_curve: Curve2D
var header_scavenging_curves: Dictionary = {}

# Estado
var current_backpressure: float = 1.0  # em bar (relativo à pressão atmosférica)
var exhaust_flow_rate: float = 0.0    # kg/s
var exhaust_temperature: float = 500.0 # Kelvin
var exhaust_pressure_drop: float = 0.0 # em Pascal
var exhaust_density: float = 0.6       # kg/m³
var scavenging_factor: float = 0.0
var exhaust_pulse_strength: float = 0.0
var exhaust_pulse_phase: Array = []
var engine_type: int = EngineType.NATURALLY_ASPIRATED

# Referências
var engine: Engine
var turbo_system: TurboSystem = null

func _ready():
    initialize_default_curves()
    initialize_scavenging_system()
    initialize_header_curves()

func initialize_default_curves():
    # Curva de restrição do muffler por fluxo (kg/s)
    muffler_restriction_curve = Curve2D.new()
    muffler_restriction_curve.add_point(Vector2(0.0, 0.1))
    muffler_restriction_curve.add_point(Vector2(0.1, 0.3))
    muffler_restriction_curve.add_point(Vector2(0.2, 0.8))
    muffler_restriction_curve.add_point(Vector2(0.3, 1.5))
    
    # Curva de restrição do catalisador
    cat_restriction_curve = Curve2D.new()
    cat_restriction_curve.add_point(Vector2(0.0, 0.2))
    cat_restriction_curve.add_point(Vector2(0.1, 0.4))
    cat_restriction_curve.add_point(Vector2(0.2, 0.9))
    cat_restriction_curve.add_point(Vector2(0.3, 1.8))
    
    # Curva de densidade do ar por temperatura
    temperature_density_curve = Curve2D.new()
    temperature_density_curve.add_point(Vector2(300, 1.16))  # 27°C
    temperature_density_curve.add_point(Vector2(400, 0.87))   # 127°C
    temperature_density_curve.add_point(Vector2(600, 0.58))   # 327°C
    temperature_density_curve.add_point(Vector2(1000, 0.35))  # 727°C
    
    # Curva de fluxo de exaustão por RPM
    rpm_flow_curve = Curve2D.new()
    rpm_flow_curve.add_point(Vector2(0.0, 0.0))
    rpm_flow_curve.add_point(Vector2(0.3, 0.4))   # 30% RPM
    rpm_flow_curve.add_point(Vector2(0.6, 0.8))   # 60% RPM
    rpm_flow_curve.add_point(Vector2(1.0, 1.0))   # 100% RPM
    rpm_flow_curve.add_point(Vector2(1.2, 1.1))   # 120% RPM

func initialize_scavenging_system():
    scavenging_efficiency_curve = Curve2D.new()
    scavenging_efficiency_curve.add_point(Vector2(0.0, 0.0))
    scavenging_efficiency_curve.add_point(Vector2(0.5, 0.2))
    scavenging_efficiency_curve.add_point(Vector2(0.8, 0.4))  # Pico em ~80% do RPM de sintonia
    scavenging_efficiency_curve.add_point(Vector2(1.0, 0.3))
    scavenging_efficiency_curve.add_point(Vector2(1.2, 0.1))
    
    # Inicializar fases dos pulsos por cilindro
    if engine:
        exhaust_pulse_phase.resize(engine.cylinder_count)
        for i in engine.cylinder_count:
            exhaust_pulse_phase[i] = 0.0

func initialize_header_curves():
    # Curvas de eficiência de scavenging por tipo de header
    header_scavenging_curves = {
        HeaderType.LOG_MANIFOLD: create_curve([0.0, 0.05, 0.1, 0.05, 0.0]),
        HeaderType.SHORT_TUBE: create_curve([0.0, 0.15, 0.25, 0.15, 0.05]),
        HeaderType.LONG_TUBE: create_curve([0.1, 0.25, 0.35, 0.2, 0.1]),
        HeaderType.EQUAL_LENGTH: create_curve([0.0, 0.2, 0.4, 0.3, 0.1]),
        HeaderType.TRI_Y: create_curve([0.05, 0.3, 0.45, 0.35, 0.15]),
        HeaderType.EXOTIC_TUNED: create_curve([0.1, 0.35, 0.5, 0.45, 0.2])
    }

func create_curve(points: Array) -> Curve2D:
    var curve = Curve2D.new()
    for i in range(points.size()):
        curve.add_point(Vector2(i * 0.3, points[i]))
    return curve

func connect_to_engine(engine_node: Engine, turbo_node: TurboSystem = null):
    engine = engine_node
    turbo_system = turbo_node
    if turbo_system:
        engine_type = EngineType.FORCED_INDUCTION
    
    # Re-inicializar sistema de scavenging com contagem de cilindros correta
    initialize_scavenging_system()

func update(delta: float, rpm: float, air_flow: float, combustion_temp: float):
    # 1. Calcular fluxo de exaustão
    calculate_exhaust_flow(rpm, air_flow, combustion_temp)
    
    # 2. Calcular densidade do gás de exaustão
    calculate_exhaust_density(combustion_temp)
    
    # 3. Calcular perda de pressão no sistema
    calculate_pressure_drop()
    
    # 4. Calcular backpressure final
    calculate_final_backpressure()
    
    # 5. Calcular efeito de scavenging
    calculate_scavenging_effect(delta, rpm)
    
    # 6. Atualizar sistemas dependentes
    update_dependent_systems()

func calculate_exhaust_flow(rpm: float, air_flow: float, temp: float):
    # Baseado no fluxo de ar e temperatura
    var rpm_normalized = clamp(rpm / EngineConfig.redline_rpm, 0.0, 1.2)
    var flow_factor = rpm_flow_curve.sample(rpm_normalized)
    
    # Fluxo de exaustão = fluxo de ar + combustível (simplificado)
    exhaust_flow_rate = air_flow * 0.95 * flow_factor
    
    # Temperatura do escapamento
    exhaust_temperature = temp * 0.85 - 50.0

func calculate_exhaust_density(combustion_temp: float):
    # Usando curva de densidade por temperatura
    var temp_normalized = clamp(exhaust_temperature, 300, 1200)
    var density_factor = temperature_density_curve.sample(temp_normalized)
    
    # Densidade baseada em gás ideal
    exhaust_density = (101325 * 0.02897) / (8.314 * exhaust_temperature) * density_factor

func calculate_pressure_drop():
    # 1. Perda no tubo reto (Darcy-Weisbach)
    var velocity = exhaust_flow_rate / (PI * pow(exhaust_diameter/2, 2) * exhaust_density)
    var reynolds = velocity * exhaust_diameter * exhaust_density / (1.8e-5)
    var friction_factor = calculate_friction_factor(reynolds)
    
    var pipe_loss = friction_factor * (exhaust_length / exhaust_diameter) * \
                    (exhaust_density * pow(velocity, 2)) / 2
    
    # 2. Perda nos componentes
    var component_loss = 0.0
    
    # Muffler
    var muffler_k = muffler_restriction_curve.sample(exhaust_flow_rate) * (1.0 + muffler_type * 0.5)
    component_loss += muffler_k * (exhaust_density * pow(velocity, 2)) / 2
    
    # Catalisador
    if has_catalytic_converter:
        var cat_k = cat_restriction_curve.sample(exhaust_flow_rate)
        component_loss += cat_k * (exhaust_density * pow(velocity, 2)) / 2
    
    # 3. Perda nos headers
    var header_loss = calculate_header_specific_loss()
    
    # 4. Perda total
    exhaust_pressure_drop = pipe_loss + component_loss + header_loss

func calculate_friction_factor(reynolds: float) -> float:
    if reynolds < 2000:
        return 64 / reynolds  # Laminar
    else:
        # Colebrook-White approximation
        var roughness_ratio = exhaust_material_roughness / exhaust_diameter
        return pow(0.25 / log10(roughness_ratio/3.7 + 5.74/pow(reynolds, 0.9)), 2)

func calculate_header_specific_loss() -> float:
    var loss = 0.0
    
    # Perda em curvas (depende do tipo de header)
    var bend_count = 0
    var bend_factor = 1.0
    
    match header_type:
        HeaderType.LOG_MANIFOLD:
            bend_count = 4
            bend_factor = 1.5
        HeaderType.SHORT_TUBE:
            bend_count = 2
            bend_factor = 1.2
        HeaderType.LONG_TUBE:
            bend_count = 3
            bend_factor = 1.3
        HeaderType.EQUAL_LENGTH:
            bend_count = 6
            bend_factor = 1.1  # Curvas suaves
        HeaderType.TRI_Y:
            bend_count = 8
            bend_factor = 1.4
        HeaderType.EXOTIC_TUNED:
            bend_count = 4
            bend_factor = 1.0  # Curvas otimizadas
    
    # Perda equivalente = 30% de um tubo reto por curva
    var bend_loss = header_primary_length * 0.3 * bend_count * bend_factor
    
    # Perda no coletor
    var collector_area_ratio = pow(header_collector_diameter / header_primary_diameter, 2)
    var collector_loss = collector_area_ratio > 1.0 ? 0.5 / collector_area_ratio : 1.0
    
    return bend_loss * collector_loss

func calculate_final_backpressure():
    current_backpressure = 1.0 + (exhaust_pressure_drop / 101325.0)
    
    # Fator turbo
    if engine_type == EngineType.FORCED_INDUCTION && turbo_system:
        current_backpressure *= turbo_backpressure_factor
    
    # Limitar valores extremos
    current_backpressure = clamp(current_backpressure, 1.0, 5.0)

func calculate_scavenging_effect(delta: float, rpm: float):
    if not engine:
        return
    
    # Calcular força do pulso de exaustão baseado no fluxo e RPM
    var base_pulse = exhaust_flow_rate * 0.1 * (rpm / 1000.0)
    
    # Atualizar fase dos pulsos para cada cilindro
    var angle_per_sec = rpm / 60.0 * 360.0
    for i in engine.cylinder_count:
        exhaust_pulse_phase[i] = fmod(exhaust_pulse_phase[i] + angle_per_sec * delta, 360.0)
        
        # Simular pulso de exaustão quando a válvula abre
        if engine.cylinder_head.is_exhaust_valve_open(i):
            var valve_open_percent = engine.cylinder_head.get_exhaust_valve_open_percent(i)
            exhaust_pulse_strength = base_pulse * valve_open_percent
    
    # Selecionar curva de scavenging baseada no tipo de header
    var scavenging_curve = header_scavenging_curves.get(header_type, header_scavenging_curves[HeaderType.LOG_MANIFOLD])
    
    # Calcular eficiência usando a curva específica
    var rpm_ratio = rpm / calculate_tuning_rpm()
    var base_efficiency = scavenging_curve.sample(rpm_ratio)
    
    # Aplicar fatores de qualidade
    scavenging_factor = base_efficiency * get_header_quality_factor() * calculate_header_length_factor()
    
    # Aplicar efeito de ressonância (onda de pressão negativa)
    var resonance_boost = calculate_resonance_boost(rpm)
    scavenging_factor *= resonance_boost
    
    # Limitar valor máximo
    scavenging_factor = clamp(scavenging_factor, 0.0, 0.6)

func calculate_resonance_boost(rpm: float) -> float:
    # Calcular tempo de percurso do pulso no escapamento
    # Velocidade do som = 331 + 0.6*T°C
    var sound_speed = 331 + 0.6 * (exhaust_temperature - 273)
    var travel_time = exhaust_length / sound_speed
    
    # Calcular RPM ideal para ressonância
    var ideal_rpm = 120 / (travel_time * engine.cylinder_count / 2)
    
    # Quão próximo estamos do RPM ideal
    var rpm_diff = abs(rpm - ideal_rpm)
    var rpm_range = ideal_rpm * 0.2  # 20% de margem
    
    # Fator de ressonância (1.0 = sem efeito, >1.0 = ressonância positiva)
    return max(1.0, 1.5 - (rpm_diff / rpm_range))

func calculate_tuning_rpm() -> float:
    # Fórmula simplificada para RPM de sintonia:
    # RPM = 84000 / Comprimento do tubo (cm)
    var length_cm = header_primary_length * 100
    var base_rpm = 84000.0 / length_cm
    
    # Fatores de ajuste por tipo de header
    match header_type:
        HeaderType.EQUAL_LENGTH:
            return base_rpm * 1.1
        HeaderType.LONG_TUBE:
            return base_rpm * 0.85
        HeaderType.TRI_Y:
            return base_rpm * 0.95
        HeaderType.EXOTIC_TUNED:
            return base_rpm * 1.2
        _:
            return base_rpm

func calculate_header_length_factor() -> float:
    return clamp(header_primary_length / 1.5, 0.8, 1.5)

func get_header_quality_factor() -> float:
    # Fator de qualidade baseado no tipo de header
    match header_type:
        HeaderType.LOG_MANIFOLD: return 0.7  # Baixa eficiência
        HeaderType.SHORT_TUBE: return 0.85
        HeaderType.LONG_TUBE: return 0.9
        HeaderType.EQUAL_LENGTH: return 1.0  # Máxima eficiência
        HeaderType.TRI_Y: return 0.95
        HeaderType.EXOTIC_TUNED: return 1.2  # Projeto otimizado
    return 1.0

func apply_scavenging_benefits():
    if not engine:
        return
    
    # Aplicar benefícios do scavenging na eficiência volumétrica
    if engine_type == EngineType.NATURALLY_ASPIRATED:
        engine.cylinder_head.volumetric_efficiency += scavenging_factor * 0.25
    
    # Reduzir contaminação da nova mistura por gases residuais
    if engine.combustion_system:
        engine.combustion_system.residual_gas_fraction = max(
            0.05, 
            0.15 - scavenging_factor * 0.1
        )

func update_dependent_systems():
    # Atualizar turbo system
    if turbo_system:
        turbo_system.current_backpressure = current_backpressure
        turbo_system.exhaust_flow_rate = exhaust_flow_rate
        turbo_system.exhaust_temperature = exhaust_temperature
    
    # Atualizar emission system
    if engine.emission_system:
        engine.emission_system.exhaust_backpressure = current_backpressure
        engine.emission_system.exhaust_temperature = exhaust_temperature
        engine.emission_system.exhaust_flow_rate = exhaust_flow_rate
    
    # Aplicar benefícios do scavenging
    apply_scavenging_benefits()

func get_backpressure() -> float:
    return current_backpressure

func get_exhaust_temperature() -> float:
    return exhaust_temperature

# API para configuração do sistema
func configure_exhaust(diameter: float, length: float, roughness: float, 
                      has_cat: bool, muffler_type: int):
    exhaust_diameter = diameter
    exhaust_length = length
    exhaust_material_roughness = roughness
    has_catalytic_converter = has_cat
    muffler_type = muffler_type

func configure_headers(
    type: int, 
    primary_length: float, 
    primary_diameter: float,
    secondary_length: float = 0.0, 
    collector_diameter: float = 0.0,
    material_roughness: float = 0.00005
):
    header_type = type
    header_primary_length = primary_length
    header_primary_diameter = primary_diameter
    header_secondary_length = secondary_length
    header_collector_diameter = collector_diameter
    header_material_roughness = material_roughness
    
    # Atualizar parâmetros de comprimento para cálculo
    exhaust_length = calculate_effective_header_length()
    exhaust_diameter = header_primary_diameter

func calculate_effective_header_length() -> float:
    match header_type:
        HeaderType.TRI_Y, HeaderType.EXOTIC_TUNED:
            return (header_primary_length + header_secondary_length) * 0.7
        _:
            return header_primary_length

# Função para debug
func get_debug_info() -> Dictionary:
    return {
        "backpressure_bar": current_backpressure,
        "flow_rate_kg_s": exhaust_flow_rate,
        "temperature_C": exhaust_temperature - 273.15,
        "pressure_drop_kPa": exhaust_pressure_drop / 1000,
        "density_kg_m3": exhaust_density,
        "scavenging_factor": scavenging_factor,
        "exhaust_pulse_strength": exhaust_pulse_strength,
        "header_type": get_header_type_name(),
        "header_primary_length": header_primary_length,
        "header_primary_diameter": header_primary_diameter,
        "tuning_rpm": calculate_tuning_rpm()
    }

func get_header_type_name() -> String:
    match header_type:
        HeaderType.LOG_MANIFOLD: return "Log Manifold"
        HeaderType.SHORT_TUBE: return "Short Tube"
        HeaderType.LONG_TUBE: return "Long Tube"
        HeaderType.EQUAL_LENGTH: return "Equal Length"
        HeaderType.TRI_Y: return "Tri-Y (4-2-1)"
        HeaderType.EXOTIC_TUNED: return "Exotic Tuned"
    return "Unknown"