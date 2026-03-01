class_name Transmission
extends Node

signal gear_changed(new_gear)
signal gear_shift_failed(gear)
signal overheat(temp)
signal failure

enum Type {MANUAL, AUTOMATIC, CVT, DCT}
enum Drivetrain {FWD, RWD, AWD}
enum GearType { HELICAL, STRAIGHT }  # Helicoidais (padrão) vs Retas (competição)

# Configuração
export(Type) var type = Type.MANUAL
export(Drivetrain) var drivetrain = Drivetrain.RWD
export(GearType) var gear_type = GearType.HELICAL
export(Array, float) var gear_ratios = [3.5, 2.5, 1.8, 1.3, 1.0, 0.8]
export(float) var final_drive = 3.5
export(float) var shift_time = 0.3
export(float) var shift_quality = 1.0
export(float) var max_temp = 150.0
export(float) var power_shift_penalty = 2.0
export(float) var dry_shift_damage = 0.05
export(Curve) var clutch_curve
export(Curve) var torque_converter_curve
export(Curve) var cvt_ratio_curve
export(Curve) var wear_curve
export(Curve) var thermal_efficiency_curve

# Propriedades específicas por tipo de engrenagem
export(float) var helical_gear_efficiency = 0.96  # 96% de eficiência
export(float) var helical_gear_noise_multiplier = 0.7  # 70% do ruído
export(float) var helical_gear_wear_rate = 1.0  # desgaste normal
export(float) var helical_impact_resistance = 0.6  # Menor resistência a impactos

export(float) var straight_gear_efficiency = 0.99  # 99% de eficiência
export(float) var straight_gear_noise_multiplier = 2.0  # 2x mais ruído
export(float) var straight_gear_wear_rate = 1.8  # 80% mais desgaste
export(float) var straight_impact_resistance = 1.8  # 80% mais resistência a impactos

# Estado
var current_gear = 0
var clutch_position = 1.0
var output_rpm = 0.0
var output_torque = 0.0
var temperature = 30.0
var vibration_level = 0.0
var shift_in_progress = false
var shift_progress = 0.0
var target_gear = 0
var last_gear = 0
var gear_wear = []
var synchro_wear = []
var is_failed = false
var torque_cut_active = false
var torque_cut_timer = 0.0

func _ready():
    gear_wear.resize(gear_ratios.size())
    gear_wear.fill(0.0)
    synchro_wear.resize(gear_ratios.size())
    synchro_wear.fill(0.0)
    configure_curves()

func configure_curves():
    if !clutch_curve:
        clutch_curve = Curve.new()
        clutch_curve.add_point(Vector2(0.0, 0.0))
        clutch_curve.add_point(Vector2(0.3, 0.2))
        clutch_curve.add_point(Vector2(0.7, 0.8))
        clutch_curve.add_point(Vector2(1.0, 1.0))
    
    if !torque_converter_curve:
        torque_converter_curve = Curve.new()
        torque_converter_curve.add_point(Vector2(0.0, 2.0))
        torque_converter_curve.add_point(Vector2(0.4, 1.5))
        torque_converter_curve.add_point(Vector2(0.8, 1.0))
    
    if !cvt_ratio_curve:
        cvt_ratio_curve = Curve.new()
        cvt_ratio_curve.add_point(Vector2(0.0, 3.5))
        cvt_ratio_curve.add_point(Vector2(0.5, 1.8))
        cvt_ratio_curve.add_point(Vector2(1.0, 0.8))
    
    if !wear_curve:
        wear_curve = Curve.new()
        wear_curve.add_point(Vector2(0.0, 0.1))
        wear_curve.add_point(Vector2(0.5, 0.5))
        wear_curve.add_point(Vector2(1.0, 2.0))
    
    if !thermal_efficiency_curve:
        thermal_efficiency_curve = Curve.new()
        thermal_efficiency_curve.add_point(Vector2(0.0, 1.0))
        thermal_efficiency_curve.add_point(Vector2(0.7, 0.9))
        thermal_efficiency_curve.add_point(Vector2(1.0, 0.7))

func update(delta, clutch_input, engine_rpm, engine_torque):
    if is_failed: 
        output_torque = 0.0
        return
    
    # Atualizar embreagem
    clutch_position = clutch_curve.interpolate(clutch_input)
    
    # Processar troca de marcha
    _process_gear_shift(delta, engine_rpm)
    
    # Calcular relação atual
    var ratio = _get_current_ratio()
    output_rpm = engine_rpm / ratio if ratio > 0 else 0.0
    
    # Calcular torque base
    var base_torque = engine_torque * ratio
    
    # Aplicar propriedades baseadas no tipo de engrenagem
    var type_efficiency = helical_gear_efficiency
    var type_noise = helical_gear_noise_multiplier
    var type_wear = helical_gear_wear_rate
    var impact_resistance = helical_impact_resistance
    
    if gear_type == GearType.STRAIGHT:
        type_efficiency = straight_gear_efficiency
        type_noise = straight_gear_noise_multiplier
        type_wear = straight_gear_wear_rate
        impact_resistance = straight_impact_resistance
    
    # Aplicar eficiência térmica
    var thermal_eff = thermal_efficiency_curve.interpolate(temperature / max_temp)
    output_torque = base_torque * type_efficiency * thermal_eff
    
    # Atualizar temperatura
    var heat_generated = abs(output_torque) * delta * 0.0005
    temperature = min(temperature + heat_generated, max_temp * 1.2)
    
    # Atualizar vibração com fator de ruído
    _update_vibration(engine_rpm, delta, type_noise)
    
    # Verificar falha catastrófica com resistência a impactos
    if temperature > max_temp && randf() < (0.001 / impact_resistance):
        fail_transmission()

func shift_up():
    if is_failed || shift_in_progress || current_gear >= gear_ratios.size():
        return
    _initiate_shift(current_gear + 1)

func shift_down():
    if is_failed || shift_in_progress || current_gear <= -1:
        return
    _initiate_shift(current_gear - 1)

func _initiate_shift(gear):
    # Verificar falha catastrófica com resistência a impactos
    var impact_resistance = helical_impact_resistance
    if gear_type == GearType.STRAIGHT:
        impact_resistance = straight_impact_resistance
        
    if temperature > 150.0 and randf() < ((temperature - 150.0) * 0.001 / impact_resistance):
        fail_transmission()
        return
    
    # Verificar se a marcha pode ser engatada
    if gear > 0 && _get_gear_health(gear) < 0.1:
        emit_signal("gear_shift_failed", gear)
        return
    
    target_gear = gear
    last_gear = current_gear
    shift_in_progress = true
    shift_progress = 0.0
    
    # Verificar sincronização
    var rpm_diff = abs(engine_rpm - _get_target_rpm())
    var dry_shift = clutch_position < 0.1
    if !_attempt_synchronization(gear, rpm_diff, dry_shift):
        emit_signal("gear_shift_failed", gear)
        shift_in_progress = false
        return
    
    # Ativar corte de torque se necessário
    if type == Type.MANUAL && throttle_input > 0.5:
        activate_torque_cut(0.1)
    
    # Engate a seco - dano aumentado
    if dry_shift:
        apply_dry_shift_damage(gear, dry_shift_damage)

func _process_gear_shift(delta, engine_rpm):
    if shift_in_progress:
        # Tempo de sincronização baseado na diferença de RPM
        var rpm_diff = abs(engine_rpm - _get_target_rpm())
        var sync_time = shift_time * (1.0 + rpm_diff * 0.001) / shift_quality
        
        shift_progress += delta / sync_time
        
        if shift_progress >= 1.0:
            current_gear = target_gear
            shift_in_progress = false
            emit_signal("gear_changed", current_gear)
        else:
            # Rev-matching
            var target_rpm = _get_target_rpm()
            engine_rpm = lerp(engine_rpm, target_rpm, shift_progress)
            
            # Vibração durante a troca
            vibration_level += 0.3 * sin(shift_progress * PI * 10)

func _attempt_synchronization(gear, rpm_diff, dry_shift):
    if gear <= 0: 
        return true
    
    # Fator de dificuldade para engate a seco
    var difficulty = 1.0 + float(dry_shift) * 0.5
    
    # Aplicar propriedades do tipo de engrenagem
    var wear_rate = helical_gear_wear_rate
    if gear_type == GearType.STRAIGHT:
        wear_rate = straight_gear_wear_rate
    
    # Chance de falha baseada em desgaste e diferença de RPM
    var failure_chance = (
        synchro_wear[gear-1] * 0.5 + 
        clamp(rpm_diff / 1000.0, 0.0, 0.5)
    ) * difficulty
    
    # Aplicar desgaste
    var wear_amount = 0.001 * (1.0 + rpm_diff/500.0) * difficulty * wear_rate
    synchro_wear[gear-1] = min(synchro_wear[gear-1] + wear_amount, 1.0)
    
    # Power shifting - desgaste adicional
    if throttle_input > 0.8 && dry_shift:
        synchro_wear[gear-1] += wear_amount * power_shift_penalty
    
    # Verificar falha
    if randf() < failure_chance:
        return false
    return true

func _update_vibration(rpm, delta, noise_factor):
    var rpm_factor = clamp(rpm / 6000.0, 0.0, 1.0)
    var wear_factor = _get_average_wear()
    var temp_factor = clamp((temperature - 80.0) / 70.0, 0.0, 1.0)
    
    vibration_level = lerp(
        vibration_level,
        (rpm_factor * 0.6 + wear_factor * 0.3 + temp_factor * 0.1) * noise_factor,
        delta * 5.0
    )

func _get_current_ratio() -> float:
    match type:
        Type.CVT:
            return cvt_ratio_curve.interpolate(throttle_input) * final_drive
        _:
            if current_gear == 0: return 0.0
            if current_gear == -1: return gear_ratios[0] * final_drive * -1
            return gear_ratios[current_gear-1] * final_drive

func _get_target_rpm() -> float:
    return output_rpm * _get_current_ratio_for_gear(target_gear)

func _get_current_ratio_for_gear(gear: int) -> float:
    match type:
        Type.CVT:
            return cvt_ratio_curve.interpolate(throttle_input) * final_drive
        _:
            if gear == 0: return 0.0
            if gear == -1: return gear_ratios[0] * final_drive * -1
            return gear_ratios[gear-1] * final_drive

func _get_average_wear() -> float:
    var total = 0.0
    for w in gear_wear: total += w
    for w in synchro_wear: total += w
    return total / (gear_wear.size() + synchro_wear.size())

func _get_gear_health(gear: int) -> float:
    if gear <= 0 || gear > gear_wear.size(): 
        return 1.0
    return 1.0 - gear_wear[gear-1]

func set_neutral():
    current_gear = 0
    emit_signal("gear_changed", 0)

func fail_transmission():
    is_failed = true
    emit_signal("failure")

func apply_dry_shift_damage(gear: int, damage: float):
    if gear > 0 && gear <= gear_wear.size():
        # Engrenagens retas sofrem menos dano por impacto
        var adjusted_damage = damage
        if gear_type == GearType.STRAIGHT:
            adjusted_damage *= 0.7  # 30% menos dano
        
        gear_wear[gear-1] = min(gear_wear[gear-1] + adjusted_damage, 1.0)

func activate_torque_cut(duration: float):
    torque_cut_active = true
    torque_cut_timer = duration

func get_temperature() -> float:
    return temperature

func get_vibration_level() -> float:
    return vibration_level

func get_average_wear() -> float:
    return _get_average_wear()