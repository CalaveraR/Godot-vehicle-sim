class_name IgnitionSystem
extends Node

# ======================
# VERSÃO 3.0 - SISTEMA DE IGNIÇÃO COMPLETO
# ======================
# Características principais:
# - ✅ 100% compatível com Engine 3.1, CombustionSystem 3.0, CylinderHead 3.0
# - ✅ Sistema de ignição realista com avanço eletrônico
# - ✅ Curvas de avanço, energia e eficiência
# - ✅ Sistema de falhas e diagnóstico completo
# - ✅ Suporte a diferentes tipos de ignição (distribuidor, coil-on-plug)
# - ✅ Integração com detonação e anti-detonacao
# ======================

# ======================
# ENUMS E CONFIGURAÇÕES
# ======================
enum IgnitionType {
    SPARK,           # Ignição por centelha (gasolina/etanol)
    COMPRESSION,     # Ignição por compressão (diesel)
    PLASMA,          # Ignição por plasma (futuro)
    WANKEL_IGNITION  # Ignição para Wankel
}

enum FailureType {
    NONE,
    WEAK_SPARK,
    INTERMITTENT,
    MISFIRE,
    COIL_FAILURE,
    TIMING_ERROR
}

enum IgnitionSystemType {
    COIL_PER_CYLINDER,
    DISTRIBUTOR,
    WASTE_SPARK,
    DIRECT_FIRE
}

# ======================
# PARÂMETROS CONFIGURÁVEIS
# ======================
export(IgnitionType) var ignition_type = IgnitionType.SPARK
export(IgnitionSystemType) var ignition_system_type = IgnitionSystemType.COIL_PER_CYLINDER
export var base_timing: float = 10.0           # Graus antes do PMS
export var max_advance: float = 35.0           # Máximo absoluto
export var min_advance: float = -5.0           # Mínimo (atraso)
export var rev_limit_cut: float = 0.8          # Corte de ignição no limitador
export var spark_energy_base: float = 1.0      # Energia base da centelha

# Configurações específicas do distribuidor
export var distributor_max_rpm: float = 7000.0
export var distributor_spark_strength: float = 0.85
export var distributor_max_advance: float = 25.0

# ======================
# ESTADO DINÂMICO
# ======================
var current_timing: float = 0.0
var dwell_time: float = 2.5                    # ms
var spark_energy: float = 1.0
var failure_mode: int = FailureType.NONE
var failure_severity: float = 0.0
var coil_charge: float = 1.0
var last_spark_time: float = 0.0
var current_cylinder: int = 0
var misfire_chance: float = 0.0
var spark_efficiency: float = 1.0
var timing_retard: float = 0.0                 # Retardo por detonação

# ======================
# SISTEMA DE AVANÇO
# ======================
var advance_curve: Curve
var dwell_curve: Curve
var energy_curve: Curve
var temperature_advance_curve: Curve
var knock_retard_curve: Curve

# ======================
# ESTATÍSTICAS E DIAGNÓSTICO
# ======================
var spark_count: int = 0
var misfire_count: int = 0
var total_spark_energy: float = 0.0
var spark_history: Array = []
var cylinder_timing: Array = []                # Timing individual por cilindro

# ======================
# REFERÊNCIAS
# ======================
var engine: Engine
var combustion_system: Node
var fuel_system: Node
var cylinder_head: CylinderHead
var diagnostic_system: Node

# ======================
# SINAIS
# ======================
signal spark_energy_changed(energy: float)
signal ignition_timing_changed(timing: float)
signal misfire_detected(cylinder: int, reason: String)
signal coil_charge_changed(charge: float)
signal system_failure(failure_type: int, severity: float)

# ======================
# CONSTANTES
# ======================
const MIN_SPARK_ENERGY: float = 0.3
const MAX_SPARK_ENERGY: float = 1.5
const DWELL_TIME_BASE: float = 2.5
const SPARK_DURATION: float = 1.5

# ======================
# INICIALIZAÇÃO
# ======================
func _ready():
    initialize_ignition_system()
    create_default_curves()
    initialize_cylinder_arrays()
    
    # Conectar sinais do engine se disponível
    if EngineConfig and EngineConfig.has_signal("engine_load_changed"):
        EngineConfig.engine_load_changed.connect(_on_engine_load_changed)

func initialize_ignition_system():
    """Inicializa o sistema de ignição com valores padrão"""
    current_timing = base_timing
    spark_energy = spark_energy_base
    coil_charge = 1.0
    
    # Configurar baseado no tipo de ignição
    match ignition_type:
        IgnitionType.COMPRESSION:
            # Diesel não tem sistema de ignição por centelha
            spark_energy = 0.0
        IgnitionType.WANKEL_IGNITION:
            # Wankel tem características específicas
            base_timing = 5.0
            max_advance = 25.0

func initialize_cylinder_arrays():
    """Inicializa arrays para múltiplos cilindros"""
    if engine:
        var cylinder_count = engine.get_cylinder_count()
        cylinder_timing.resize(cylinder_count)
        
        for i in range(cylinder_count):
            cylinder_timing[i] = base_timing

func create_default_curves():
    """Cria curvas de ignição padrão"""
    
    # Curva de avanço vs RPM
    advance_curve = Curve.new()
    advance_curve.add_point(Vector2(0.0, 0.0))      # Idle: avanço base
    advance_curve.add_point(Vector2(0.2, 5.0))      # Baixo RPM
    advance_curve.add_point(Vector2(0.4, 15.0))     # RPM médio-baixo
    advance_curve.add_point(Vector2(0.6, 25.0))     # Torque máximo
    advance_curve.add_point(Vector2(0.8, 20.0))     # Potência máxima
    advance_curve.add_point(Vector2(1.0, 15.0))     # Redline
    advance_curve.add_point(Vector2(1.2, 10.0))     # Acima da redline
    
    # Curva de dwell time vs RPM
    dwell_curve = Curve.new()
    dwell_curve.add_point(Vector2(0.0, 0.1))        # RPM baixo = mais tempo
    dwell_curve.add_point(Vector2(0.5, 0.25))
    dwell_curve.add_point(Vector2(1.0, 0.4))        # RPM alto = menos tempo
    dwell_curve.add_point(Vector2(1.2, 0.35))
    
    # Curva de energia vs Temperatura
    energy_curve = Curve.new()
    energy_curve.add_point(Vector2(0.0, 0.7))       # Muito frio (70°C): 70%
    energy_curve.add_point(Vector2(0.3, 0.95))      # Ideal (90°C): 95%
    energy_curve.add_point(Vector2(0.6, 1.0))       # Ótimo (100°C): 100%
    energy_curve.add_point(Vector2(1.0, 0.8))       # Superaquecimento (170°C): 80%
    
    # Curva de avanço por temperatura
    temperature_advance_curve = Curve.new()
    temperature_advance_curve.add_point(Vector2(0.0, 5.0))   # Frio: +5°
    temperature_advance_curve.add_point(Vector2(0.5, 0.0))   # Normal: 0°
    temperature_advance_curve.add_point(Vector2(1.0, -5.0))  # Quente: -5°
    
    # Curva de retardo por detonação
    knock_retard_curve = Curve.new()
    knock_retard_curve.add_point(Vector2(0.0, 0.0))     # Sem detonação
    knock_retard_curve.add_point(Vector2(0.5, 2.0))     # Detonação leve
    knock_retard_curve.add_point(Vector2(1.0, 8.0))     # Detonação severa

# ======================
# ATUALIZAÇÃO PRINCIPAL
# ======================
func update(delta: float):
    """Atualiza o sistema de ignição - chamado pelo Engine"""
    if not engine or ignition_type == IgnitionType.COMPRESSION:
        return
    
    var rpm = engine.rpm
    var load = engine.load
    var coolant_temp = engine.coolant_temp
    
    # Atualizar componentes do sistema
    update_ignition_timing(rpm, load, coolant_temp)
    update_coil_charge(delta, rpm)
    update_spark_energy(coolant_temp)
    handle_failures(delta)
    
    # Verificar se deve disparar centelha
    if should_fire_spark(rpm):
        fire_spark()

func update_ignition_timing(rpm: float, load: float, coolant_temp: float):
    """Calcula e atualiza o timing de ignição ideal"""
    var rpm_normalized = clamp(rpm / engine.redline_rpm, 0.0, 1.2)
    
    # Timing base da curva de avanço
    var advance_from_curve = advance_curve.interpolate(rpm_normalized)
    
    # Correção por carga
    var load_correction = load * 5.0  # Mais avanço em alta carga
    
    # Correção por temperatura
    var temp_normalized = clamp((coolant_temp - 70.0) / 100.0, 0.0, 1.0)
    var temp_correction = temperature_advance_curve.interpolate(temp_normalized)
    
    # Timing total
    var target_timing = base_timing + advance_from_curve + load_correction + temp_correction
    
    # Aplicar retardo por detonação
    target_timing -= timing_retard
    
    # Limitações baseadas no tipo de sistema
    if ignition_system_type == IgnitionSystemType.DISTRIBUTOR:
        var max_total_advance = base_timing + distributor_max_advance
        target_timing = clamp(target_timing, min_advance, max_total_advance)
    else:
        target_timing = clamp(target_timing, min_advance, max_advance)
    
    # Suavizar mudanças de timing
    var timing_change_rate = 100.0  # Graus/segundo
    var max_change = timing_change_rate * (1.0 / engine.rpm) if engine.rpm > 0 else timing_change_rate * 0.01
    
    current_timing = move_toward(current_timing, target_timing, max_change)
    
    # Atualizar timing por cilindro (para sistemas sequenciais)
    update_cylinder_timing()

func update_cylinder_timing():
    """Atualiza timing individual para cada cilindro"""
    if cylinder_timing.size() == 0:
        return
    
    # Para sistemas coil-on-plug, cada cilindro pode ter timing individual
    if ignition_system_type == IgnitionSystemType.COIL_PER_CYLINDER:
        # Pequenas variações entre cilindros (realismo)
        for i in range(cylinder_timing.size()):
            var variation = (randf() - 0.5) * 0.5  # ±0.25 graus
            cylinder_timing[i] = current_timing + variation
    else:
        # Sistemas com distribuidor têm o mesmo timing para todos
        for i in range(cylinder_timing.size()):
            cylinder_timing[i] = current_timing

func update_coil_charge(delta: float, rpm: float):
    """Atualiza estado de carga da bobina"""
    var rpm_normalized = clamp(rpm / engine.redline_rpm, 0.0, 1.2)
    var charge_rate = dwell_curve.interpolate(rpm_normalized)
    
    # Efeito de falhas na carga
    if failure_mode == FailureType.WEAK_SPARK:
        charge_rate *= (1.0 - failure_severity * 0.5)
    
    if failure_mode == FailureType.COIL_FAILURE:
        charge_rate *= (1.0 - failure_severity * 0.8)
    
    coil_charge = clamp(coil_charge + charge_rate * delta * 1000.0, 0.0, 1.0)
    coil_charge_changed.emit(coil_charge)

func update_spark_energy(coolant_temp: float):
    """Atualiza energia da centelha baseada nas condições"""
    var temp_normalized = clamp((coolant_temp - 70.0) / 100.0, 0.0, 1.0)
    var base_energy = energy_curve.interpolate(temp_normalized)
    
    # Aplicar força específica para distribuidor
    if ignition_system_type == IgnitionSystemType.DISTRIBUTOR:
        base_energy *= distributor_spark_strength
    
    # Efeito de falhas na energia
    if failure_mode == FailureType.WEAK_SPARK:
        base_energy *= (1.0 - failure_severity * 0.7)
    
    # Efeito do desgaste geral
    if engine and engine.has_method("get_wear_factor"):
        var wear = engine.get_wear_factor()
        base_energy *= (1.0 - wear * 0.2)
    
    spark_energy = clamp(base_energy, MIN_SPARK_ENERGY, MAX_SPARK_ENERGY)
    spark_energy_changed.emit(spark_energy)

# ======================
# SISTEMA DE CENTELHA
# ======================
func should_fire_spark(rpm: float) -> bool:
    """Verifica se é momento de disparar centelha"""
    if ignition_type != IgnitionType.SPARK and ignition_type != IgnitionType.WANKEL_IGNITION:
        return false
    
    # Cortar ignição acima do limitador
    if rpm > engine.redline_rpm * 1.05:
        return false
    
    var cylinder_count = engine.get_cylinder_count()
    var event_interval = 720.0 / cylinder_count  # Graus entre eventos
    var current_angle = engine.crankshaft.get_angle()
    var angle_in_cycle = fmod(current_angle, 720.0)
    
    # Determinar cilindro atual
    current_cylinder = int(angle_in_cycle / event_interval) % cylinder_count
    
    # Verificar se está no ponto de ignição
    var target_angle = current_cylinder * event_interval + cylinder_timing[current_cylinder]
    var angle_diff = abs(angle_in_cycle - target_angle)
    
    return angle_diff < 1.0 || (angle_diff > 359.0 && angle_diff < 361.0)

func fire_spark():
    """Dispara a centelha no cilindro atual"""
    if not engine or coil_charge < 0.3:
        return
    
    # Verificar se ocorre misfire
    if should_misfire():
        trigger_misfire()
        return
    
    # Calcular eficiência da centelha
    var actual_spark_energy = spark_energy * coil_charge
    spark_efficiency = actual_spark_energy
    
    # Registrar estatísticas
    spark_count += 1
    total_spark_energy += actual_spark_energy
    
    # ✅ COMPATÍVEL: Notificar combustion system
    if combustion_system and combustion_system.has_method("on_spark_event"):
        combustion_system.on_spark_event(current_cylinder, actual_spark_energy)
    
    # ✅ COMPATÍVEL: Notificar cylinder head
    if cylinder_head and cylinder_head.has_method("on_ignition_event"):
        cylinder_head.on_ignition_event(current_cylinder, actual_spark_energy)
    
    # Efeitos visuais e sonoros
    play_spark_sound(actual_spark_energy)
    emit_spark_effects(current_cylinder, actual_spark_energy)
    
    # Resetar sistema
    coil_charge = 0.0
    last_spark_time = OS.get_ticks_msec()
    misfire_chance = 0.0
    
    # Emitir sinais
    ignition_timing_changed.emit(current_timing)

func should_misfire() -> bool:
    """Determina se ocorre falha de ignição"""
    # 1. Falta de carga na bobina
    if coil_charge < 0.5:
        misfire_chance += 0.3
        return randf() < misfire_chance
    
    # 2. Falhas ativas no sistema
    if failure_mode != FailureType.NONE:
        var failure_chance = failure_severity * 0.8
        if randf() < failure_chance:
            return true
    
    # 3. Energia de centelha insuficiente
    if spark_energy < 0.5:
        misfire_chance += (0.5 - spark_energy) * 0.5
        if randf() < misfire_chance:
            return true
    
    # 4. Combustível inadequado
    if fuel_system and fuel_system.has_method("get_fuel_quality"):
        var fuel_quality = fuel_system.get_fuel_quality()
        if fuel_quality < 0.8 && randf() > fuel_quality:
            return true
    
    # 5. RPM muito alto para o sistema
    if engine.rpm > distributor_max_rpm && ignition_system_type == IgnitionSystemType.DISTRIBUTOR:
        var overrev_chance = (engine.rpm - distributor_max_rpm) / 1000.0
        if randf() < overrev_chance:
            return true
    
    return false

func trigger_misfire():
    """Processa uma falha de ignição"""
    misfire_count += 1
    misfire_chance = min(1.0, misfire_chance + 0.2)
    
    # Reduzir eficiência no cilindro afetado
    if combustion_system and combustion_system.has_method("set_combustion_efficiency"):
        combustion_system.set_combustion_efficiency(current_cylinder, 0.3)
    
    # Efeitos sonoros e visuais
    play_misfire_sound()
    emit_misfire_effects(current_cylinder)
    
    # Registrar falha
    var reason = "Coil: %.1f, Spark: %.1f, Failure: %d" % [
        coil_charge, spark_energy, failure_mode
    ]
    
    misfire_detected.emit(current_cylinder, reason)
    
    # Acionar luz de check engine se severo
    if failure_severity > 0.3:
        engine.trigger_check_engine("P030" + str(current_cylinder + 1))
    
    # Resetar mesmo em misfire
    coil_charge = 0.0
    last_spark_time = OS.get_ticks_msec()

# ======================
# SISTEMA DE DETONAÇÃO E ANTI-DETONAÇÃO
# ======================
func retard_timing(cylinder: int, severity: float):
    """Retarda o timing para combater detonação - COMPATÍVEL COM COMBUSTIONSYSTEM"""
    if cylinder < 0 or cylinder >= cylinder_timing.size():
        return
    
    var retard_amount = knock_retard_curve.interpolate(severity)
    timing_retard = max(timing_retard, retard_amount)
    
    # Retardo específico por cilindro em sistemas avançados
    if ignition_system_type == IgnitionSystemType.COIL_PER_CYLINDER:
        cylinder_timing[cylinder] -= retard_amount
    
    # Agendar restauração gradual do timing
    schedule_timing_restoration()

func schedule_timing_restoration():
    """Programa restauração gradual do timing após retardo"""
    # Usar timer para restaurar timing gradualmente
    var restore_timer = Timer.new()
    restore_timer.wait_time = 2.0  # 2 segundos
    restore_timer.one_shot = true
    restore_timer.timeout.connect(restore_timing)
    add_child(restore_timer)
    restore_timer.start()

func restore_timing():
    """Restaura gradualmente o timing após retardo por detonação"""
    timing_retard = max(0.0, timing_retard - 1.0)  # Reduz 1 grau por chamada
    
    # Se ainda há retardo, agenda outra restauração
    if timing_retard > 0.0:
        schedule_timing_restoration()

# ======================
# SISTEMA DE FALHAS
# ======================
func handle_failures(delta: float):
    """Gerencia falhas e degradação do sistema"""
    if failure_mode != FailureType.NONE:
        failure_severity = clamp(failure_severity + delta * 0.05, 0.0, 1.0)
        
        # Falha catastrófica em severidade máxima
        if failure_severity >= 0.95:
            trigger_catastrophic_failure()
    
    # Chance de novas falhas baseada em desgaste
    if engine and engine.has_method("get_wear_factor"):
        var wear_factor = engine.get_wear_factor()
        if randf() < wear_factor * delta * 0.001:
            initiate_random_failure()

func initiate_random_failure():
    """Inicia uma falha aleatória no sistema"""
    var failure_types = [
        FailureType.WEAK_SPARK,
        FailureType.INTERMITTENT, 
        FailureType.MISFIRE,
        FailureType.COIL_FAILURE
    ]
    
    failure_mode = failure_types[randi() % failure_types.size()]
    failure_severity = 0.1
    
    system_failure.emit(failure_mode, failure_severity)
    
    # Log específico por tipo de falha
    match failure_mode:
        FailureType.WEAK_SPARK:
            print("IgnitionSystem: Falha de centelha fraca detectada")
        FailureType.INTERMITTENT:
            print("IgnitionSystem: Falha intermitente detectada")
        FailureType.COIL_FAILURE:
            print("IgnitionSystem: Falha de bobina detectada")

func trigger_catastrophic_failure():
    """Falha catastrófica - múltiplos misfires consecutivos"""
    for i in range(3):
        trigger_misfire()
    
    # Desligar motor em caso de falha grave
    if failure_severity >= 0.95:
        engine.stall()

# ======================
# API PÚBLICA
# ======================
func get_ignition_status() -> Dictionary:
    return {
        "system_type": ignition_system_type,
        "base_timing": base_timing,
        "current_timing": current_timing,
        "spark_energy": spark_energy,
        "coil_charge": coil_charge,
        "misfire_chance": misfire_chance,
        "failure_mode": failure_mode,
        "failure_severity": failure_severity,
        "timing_retard": timing_retard,
        "spark_count": spark_count,
        "misfire_count": misfire_count
    }

func get_cylinder_timing(cylinder: int) -> float:
    """Retorna timing específico do cilindro"""
    if cylinder >= 0 and cylinder < cylinder_timing.size():
        return cylinder_timing[cylinder]
    return current_timing

func get_spark_energy() -> float:
    """Retorna energia atual da centelha - COMPATÍVEL COM COMBUSTIONSYSTEM"""
    return spark_energy

func get_current_timing() -> float:
    """Retorna timing atual - COMPATÍVEL COM COMBUSTIONSYSTEM"""
    return current_timing

func set_base_timing(new_timing: float):
    """Define o timing base do sistema"""
    base_timing = new_timing
    
    # Recalcular timing imediatamente
    if engine:
        update_ignition_timing(engine.rpm, engine.load, engine.coolant_temp)

func set_distributor_config(strength: float, max_adv: float):
    """Configura parâmetros específicos do distribuidor"""
    distributor_spark_strength = clamp(strength, 0.7, 1.0)
    distributor_max_advance = clamp(max_adv, 15.0, 40.0)

func perform_maintenance():
    """Realiza manutenção no sistema"""
    failure_mode = FailureType.NONE
    failure_severity = 0.0
    misfire_count = 0
    timing_retard = 0.0
    coil_charge = 1.0
    spark_energy = spark_energy_base

func connect_to_engine(engine_node: Engine):
    """Conecta ao motor - COMPATÍVEL COM ENGINE 3.1"""
    engine = engine_node
    initialize_cylinder_arrays()

# ======================
# UTILITÁRIOS
# ======================
func play_spark_sound(energy: float):
    """Toca som de centelha (placeholder)"""
    # Implementar lógica de áudio
    pass

func play_misfire_sound():
    """Toca som de misfire (placeholder)"""
    # Implementar lógica de áudio
    pass

func emit_spark_effects(cylinder: int, energy: float):
    """Emite efeitos visuais de centelha"""
    # Implementar efeitos visuais
    pass

func emit_misfire_effects(cylinder: int):
    """Emite efeitos visuais de misfire"""
    # Implementar efeitos visuais
    pass

func _on_engine_load_changed(load: float):
    """Callback para mudanças de carga do motor"""
    # Recalcular timing se necessário
    if engine:
        update_ignition_timing(engine.rpm, load, engine.coolant_temp)

func reset_statistics():
    """Reseta estatísticas do sistema"""
    spark_count = 0
    misfire_count = 0
    total_spark_energy = 0.0
    spark_history.clear()

func get_spark_statistics() -> Dictionary:
    """Retorna estatísticas detalhadas das centelhas"""
    var avg_energy = 0.0
    if spark_count > 0:
        avg_energy = total_spark_energy / spark_count
    
    return {
        "total_sparks": spark_count,
        "misfires": misfire_count,
        "misfire_rate": float(misfire_count) / max(1, spark_count),
        "average_energy": avg_energy,
        "current_efficiency": spark_efficiency
    }
