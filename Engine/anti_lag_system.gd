class_name AntiLagSystem
extends RefCounted

# ======================
# VERSÃO 3.1 - ANTI-LAG COMPATÍVEL
# ======================
// Melhorias:
// - ✅ 100% compatível com versão anterior
// - ✅ Integração com TurboSystem 3.1
// - ✅ Cálculos de temperatura mais precisos
// - ✅ Diferentes modos operacionais
// - ✅ Preparado para sistemas modernos
// ======================

// Estado (COMPATÍVEL)
var turbo_system: Node
var active: bool = false
var timer: float = 0.0
var exhaust_pop: bool = false

// ✅ NOVOS PARÂMETROS
var exhaust_temperature: float = 500.0
var fuel_trim: float = 0.0
var ignition_retard: float = 0.0
var turbo_pressure_target: float = 1.2

// Curvas (✅ OTIMIZADO: Curve)
var temperature_curve: Curve
var fuel_curve: Curve

func _init(system: Node):
    turbo_system = system
    _create_curves()

func _create_curves():
    """✅ OTIMIZADO: Curvas do anti-lag"""
    temperature_curve = Curve.new()
    temperature_curve.add_point(Vector2(0.0, 500.0))   // Base
    temperature_curve.add_point(Vector2(0.5, 800.0))   // Ativo
    temperature_curve.add_point(Vector2(1.0, 1200.0))  // Máximo
    
    fuel_curve = Curve.new()
    fuel_curve.add_point(Vector2(0.0, 0.0))    // Normal
    fuel_curve.add_point(Vector2(0.5, 0.1))    // Leve enrichment
    fuel_curve.add_point(Vector2(1.0, 0.25))   // Rico para anti-lag

// ======================
// MÉTODOS PRINCIPAIS (COMPATÍVEIS)
// ======================

func update(delta: float, rpm_normalized: float):
    """✅ COMPATÍVEL: Interface idêntica"""
    exhaust_pop = false
    
    if turbo_system.anti_lag_mode == turbo_system.AntiLagMode.OFF:
        active = false
        _deactivate_system()
        return
    
    var should_activate = _should_activate_anti_lag(rpm_normalized)
    
    match turbo_system.anti_lag_mode:
        turbo_system.AntiLagMode.PASSIVE:
            _update_passive_mode(delta, should_activate, rpm_normalized)
        turbo_system.AntiLagMode.ACTIVE:
            _update_active_mode(delta, should_activate, rpm_normalized)
        turbo_system.AntiLagMode.RACE_ACTIVE:
            _update_race_mode(delta, should_activate, rpm_normalized)
    
    // ✅ NOVO: Atualizar temperatura do escape
    _update_exhaust_temperature(delta)

func _should_activate_anti_lag(rpm_normalized: float) -> bool:
    """✅ COMPATÍVEL: Verifica se deve ativar"""
    return (
        turbo_system.engine_rpm >= turbo_system.anti_lag_min_rpm && 
        turbo_system.engine_throttle < 0.1 && 
        turbo_system.current_boost < turbo_system.anti_lag_boost_target
    )

func _update_passive_mode(delta: float, should_activate: bool, rpm_normalized: float):
    """✅ COMPATÍVEL: Modo passivo"""
    if should_activate:
        active = true
        turbo_system.boost_target = max(turbo_system.boost_target, turbo_system.anti_lag_boost_target * 0.7)
        turbo_system.turbo_response_rate *= 1.2
        fuel_trim = 0.05
        ignition_retard = 5.0
    else:
        active = false
        _reset_parameters()

func _update_active_mode(delta: float, should_activate: bool, rpm_normalized: float):
    """✅ COMPATÍVEL: Modo ativo"""
    if should_activate:
        active = true
        turbo_system.boost_target = max(turbo_system.boost_target, turbo_system.anti_lag_boost_target * 0.8)
        turbo_system.turbo_response_rate *= 1.5
        
        timer += delta
        if timer > 0.4:
            exhaust_pop = true
            timer = 0.0
            
        fuel_trim = 0.15
        ignition_retard = 15.0
    else:
        active = false
        timer = 0.0
        _reset_parameters()

func _update_race_mode(delta: float, should_activate: bool, rpm_normalized: float):
    """✅ COMPATÍVEL: Modo corrida"""
    active = turbo_system.engine_rpm >= turbo_system.anti_lag_min_rpm
    
    if active:
        turbo_system.boost_target = turbo_system.anti_lag_boost_target
        turbo_system.turbo_response_rate *= 2.0
        
        timer += delta
        if timer > 0.2:
            exhaust_pop = true
            timer = 0.0
            turbo_system.current_backpressure += 0.4
            
        fuel_trim = 0.25
        ignition_retard = 25.0
    
    if active && turbo_system.anti_lag_mode != turbo_system.AntiLagMode.RACE_ACTIVE && turbo_system.engine_throttle > 0.5:
        active = false

// ======================
// NOVOS MÉTODOS (✅ COMPATÍVEIS)
// ======================

func _update_exhaust_temperature(delta: float):
    """✅ NOVO: Atualiza temperatura do escape"""
    if active:
        var target_temp = temperature_curve.sample(fuel_trim * 4.0)  // 0-1 para 0-4
        exhaust_temperature = lerp(exhaust_temperature, target_temp, delta * 2.0)
        
        // ✅ COMPATÍVEL: Notificar turbo system se possível
        if turbo_system.has_method("set_exhaust_temperature"):
            turbo_system.set_exhaust_temperature(exhaust_temperature)
    else:
        // Resfriamento gradual
        exhaust_temperature = lerp(exhaust_temperature, 500.0, delta * 0.5)

func _deactivate_system():
    """✅ NOVO: Desativação completa do sistema"""
    fuel_trim = 0.0
    ignition_retard = 0.0
    exhaust_temperature = 500.0

func _reset_parameters():
    """✅ NOVO: Reset de parâmetros"""
    fuel_trim = 0.0
    ignition_retard = 0.0

// ======================
// API PÚBLICA (COMPATÍVEL)
// ======================

func get_anti_lag_data() -> Dictionary:
    """✅ COMPATÍVEL: Dados do sistema"""
    return {
        "active": active,
        "exhaust_pop": exhaust_pop,
        "exhaust_temperature": exhaust_temperature,
        "fuel_trim": fuel_trim,
        "ignition_retard": ignition_retard,
        "timer": timer,
        "turbo_pressure_target": turbo_pressure_target
    }

func set_turbo_pressure_target(target: float):
    """✅ NOVO: Define pressão alvo do turbo"""
    turbo_pressure_target = max(1.0, target)

// ======================
// MÉTODOS DE SEGURANÇA
// ======================

func is_temperature_safe() -> bool:
    """✅ NOVO: Verifica se temperatura está segura"""
    return exhaust_temperature < 1000.0

func get_turbo_stress_level() -> float:
    """✅ NOVO: Nível de estresse no turbo"""
    if !active:
        return 0.0
    
    var temp_stress = clamp((exhaust_temperature - 800.0) / 400.0, 0.0, 1.0)
    var pressure_stress = clamp((turbo_pressure_target - 1.5) / 1.5, 0.0, 1.0)
    
    return max(temp_stress, pressure_stress)
