# Representação estruturada do patch de contato do pneu com histerese
# Espaço local da roda (para física) + métricas agregadas + memória temporal
class_name ContactPatchstate

# --- Constantes de histerese ---
# NOTA: MAX_STORED_ENERGY é uma unidade abstrata, não Joules físicos
# Valor normalizado para facilitar ajuste e debug
const MAX_STORED_ENERGY := 10.0
const MIN_HYSTERESIS_FACTOR := 0.7
const HYSTERESIS_RECOVERY_FAST := 4.0
const HYSTERESIS_RECOVERY_SLOW := 0.8
const RESIDUAL_DECAY_RATE := 2.0
const ENERGY_THRESHOLD := 5.0
const SLIP_ENERGY_THRESHOLD := 0.1

# Constantes para micro-lag e efeitos direcionais
const SLIP_LAG_RATE := 8.0  # Taxa de lag exponencial do slip
const RESIDUAL_DIRECTIONAL_NOISE := 0.05  # Escala do ruído direcional pós-derrapagem
const CONFIDENCE_HYSTERESIS_MULTIPLIER := 0.5  # Confiança mínima para histerese

# --- Dados de entrada ---
var samples: Array[TireSample] = []

# --- Propriedades agregadas (espaço local da roda) ---
var center_of_pressure_local: Vector3
var average_normal_local: Vector3  # Já normalizada — não renormalizar no solver
var average_slip_local: Vector2
var lagged_slip_local: Vector2  # Slip com micro-lag para sensação de massa

# --- Métricas escalares ---
var total_contact_weight: float
var max_penetration: float
var patch_confidence: float

# --- Estado de histerese ---
#  1 Histerese simples do pneu
# stored_energy: acumula input (slip + penetração)
# recovery: decay exponencial baseado no nível de energia
var stored_energy: float = 0.0        # Energia acumulada (unidades abstratas)
var residual_energy: float = 0.0      # Energia residual após transições bruscas
var hysteresis_factor: float = 1.0    # [0.7 .. 1.0] - fator de modulação puro
var last_slip_magnitude: float = 0.0  # Para detectar transições rápidas

# --- Controle interno ---
var timestamp: float
var valid: bool = false
var contributing_samples: int = 0

# --- Inicialização ---
func _init(sample_array: Array[TireSample] = [], time: float = 0.0) -> void:
    """
    IMPORTANTE:
    Este patch é somente leitura para o solver.
    Qualquer modificação exige recalculate() ou rebuild_from_samples().
    
    Histerese: o patch mantém memória de esforços recentes para
    simular inércia térmica/mecânica da borracha.
    
    NOTA: stored_energy é unidade abstrata, não física.
    
     IMPLEMENTAÇÕES-CHAVE:
    1. Histerese simples: stored_energy += input, stored_energy -= recovery * delta
    2. Memória residual: residual_energy *= exp(-delta * decay_rate) (decay barato)
    3. Micro-lag no slip para sensação de massa
    4. Histerese modulada pela confiança da superfície
    5. Ruído direcional pós-derrapagem
    6. Reset apenas por teleporte explícito
    """
    rebuild_from_samples(sample_array, time)

# --- Métodos públicos de atualização ---

func rebuild_from_samples(new_samples: Array[TireSample], time: float) -> void:
    """Reconstrói completamente o patch a partir de novas amostras"""
    samples = new_samples
    timestamp = time
    _recalculate_aggregates()
    # Inicializa lagged_slip com o valor atual
    lagged_slip_local = average_slip_local

func recalculate() -> void:
    """Recalcula propriedades com as amostras atuais"""
    _recalculate_aggregates()

func update_hysteresis(delta: float, tire_load: float, tire_stiffness: float) -> void:
    """
    Atualiza o estado de histerese com base no contato atual
    delta: tempo desde última atualização
    tire_load: carga vertical atual no pneu
    tire_stiffness: rigidez vertical do pneu
    
     1 Histerese simples do pneu:
    stored_energy += input (slip + penetração)
    stored_energy -= recovery * delta (decay exponencial)
    
     2 Memória de energia residual:
    residual_energy *= exp(-delta * decay_rate) (decay barato)
    """
    if not valid:
        # Sem contato: decaimento mais rápido
        stored_energy *= exp(-HYSTERESIS_RECOVERY_FAST * delta)
        residual_energy *= exp(-RESIDUAL_DECAY_RATE * delta)
        _update_hysteresis_factor()
        return
    
    var current_slip_magnitude = get_average_slip_magnitude()
    
    #  1 ACÚMULO (input) da histerese simples
    # TODO: Futuramente tornar threshold dependente da carga
    if current_slip_magnitude > SLIP_ENERGY_THRESHOLD:
        var slip_energy = current_slip_magnitude * tire_load * delta
        stored_energy += slip_energy  # INPUT: slip significativo
    
    # INPUT adicional por deformação (penetração)
    if max_penetration > 0.0:
        var deformation_energy = max_penetration * tire_stiffness * delta
        stored_energy += deformation_energy  # INPUT: deformação
    
    #  2 Memória de energia residual (transições bruscas)
    var slip_change = abs(current_slip_magnitude - last_slip_magnitude)
    if slip_change > 0.2:  # Mudança brusca no slip
        residual_energy += slip_change * tire_load * 0.5  # INPUT residual
    
    # 4. Saturação (MAX_STORED_ENERGY é unidade abstrata)
    stored_energy = min(stored_energy, MAX_STORED_ENERGY)
    
    #  1 RECUPERAÇÃO (recovery) da histerese simples
    # Decay exponencial: stored_energy -= recovery * delta (implícito na multiplicação)
    var decay_rate = HYSTERESIS_RECOVERY_SLOW if stored_energy > ENERGY_THRESHOLD else HYSTERESIS_RECOVERY_FAST
    stored_energy *= exp(-decay_rate * delta)  # RECOVERY: decay exponencial
    
    #  2 Decay da memória residual (decay barato)
    residual_energy *= exp(-RESIDUAL_DECAY_RATE * delta)  # DECAY: residual_energy *= exp(-delta * decay_rate)
    
    # 6. Aplica micro-lag no slip para sensação de massa
    _apply_slip_lag(delta)
    
    # 7. Aplica ruído direcional baseado na energia residual
    _apply_directional_noise()
    
    # 8. Atualiza fator de histerese (sem confiança aqui)
    _update_hysteresis_factor()
    
    # 9. Guarda slip para próximo frame
    last_slip_magnitude = current_slip_magnitude

func reset_hysteresis() -> void:
    """
    Reseta completamente o estado de histerese (ex: após teleporte)
    AVISO: Chamar apenas em teleporte explícito para evitar popping
    """
    stored_energy = 0.0
    residual_energy = 0.0
    hysteresis_factor = 1.0
    last_slip_magnitude = 0.0
    lagged_slip_local = average_slip_local

# --- Cálculo das propriedades do patch ---
func _recalculate_aggregates() -> void:
    valid = false
    
    if samples.is_empty():
        _reset_to_default()
        return

    var weighted_pos = Vector3.ZERO
    var weighted_normal = Vector3.ZERO
    var weighted_slip = Vector2.ZERO
    
    total_contact_weight = 0.0
    max_penetration = 0.0
    patch_confidence = 0.0
    contributing_samples = 0
    
    # Processa apenas amostras válidas e com penetração positiva
    for sample in samples:
        if not sample.valid or sample.penetration <= 0.0:
            continue
            
        # Peso baseado em penetração e confiança
        var sample_weight = sample.penetration * sample.confidence
        if sample_weight <= 0.0:
            continue
            
        # Soma ponderada no espaço local da roda
        weighted_pos += sample.contact_pos_local * sample_weight
        weighted_normal += sample.contact_normal_local * sample_weight
        weighted_slip += sample.slip_vector * sample_weight
        
        total_contact_weight += sample_weight
        max_penetration = max(max_penetration, sample.penetration)
        patch_confidence += sample.confidence
        contributing_samples += 1
    
    # Verifica se há amostras contribuindo
    if total_contact_weight <= 0.0 or contributing_samples == 0:
        _reset_to_default()
        return
    
    # Calcula médias ponderadas
    center_of_pressure_local = weighted_pos / total_contact_weight
    average_normal_local = (weighted_normal / total_contact_weight).normalized()
    average_slip_local = weighted_slip / total_contact_weight
    
    # Normaliza confiança apenas entre amostras contribuintes
    patch_confidence /= float(contributing_samples)
    
    # Marca como válido
    valid = true

# --- Efeitos de feeling (micro-lag e ruído) ---
func _apply_slip_lag(delta: float) -> void:
    """
    Aplica micro-lag exponencial ao slip para sensação de massa na borracha.
    Barato e poderoso para feeling de inércia.
    """
    if valid and average_slip_local.length_squared() > 0.0:
        var lag_weight = exp(-SLIP_LAG_RATE * delta)
        lagged_slip_local = lagged_slip_local.lerp(average_slip_local, lag_weight)
    else:
        lagged_slip_local = average_slip_local

func _apply_directional_noise() -> void:
    """
    Adiciona ruído direcional baseado na energia residual.
    Cria volante "nervoso" pós-derrapagem e sensação de carcaça torcida.
    """
    if valid and residual_energy > 0.0 and lagged_slip_local.length_squared() > 0.0:
        var directional_noise = (residual_energy / MAX_STORED_ENERGY) * RESIDUAL_DIRECTIONAL_NOISE
        var orthogonal_component = lagged_slip_local.orthogonal() * directional_noise
        lagged_slip_local += orthogonal_component

# --- Cálculo do fator de histerese ---
func _update_hysteresis_factor() -> void:
    """
    Converte energia armazenada em fator de histerese [0.7..1.0].
    ATENÇÃO: Não inclui patch_confidence aqui.
    
     Tradução direta da histerese simples para fator útil:
    stored_energy → hysteresis_factor [0.7..1.0]
    """
    var total_energy = stored_energy + residual_energy * 0.3
    var normalized_energy = clamp(total_energy / MAX_STORED_ENERGY, 0.0, 1.0)
    
    # Curva de resposta: lenta para cair, rápida para subir
    hysteresis_factor = lerp(
        1.0,
        MIN_HYSTERESIS_FACTOR,
        sqrt(normalized_energy)  # sqrt para resposta não-linear
    )

# --- Reset para estado padrão (para pooling) ---
func reset() -> void:
    """Reseta o patch para estado inicial (uso com pooling)"""
    samples.clear()
    timestamp = 0.0
    _reset_to_default()

func _reset_to_default() -> void:
    """Reset interno de valores para estado padrão"""
    center_of_pressure_local = Vector3.ZERO
    average_normal_local = Vector3.UP  # Normal padrão já normalizada
    average_slip_local = Vector2.ZERO
    lagged_slip_local = Vector2.ZERO
    
    total_contact_weight = 0.0
    max_penetration = 0.0
    patch_confidence = 0.0
    contributing_samples = 0
    valid = false
    
    # NOTA: histerese NÃO é resetada aqui (mantida entre frames)
    # Teleporte explícito deve chamar reset_hysteresis()

# --- Métodos utilitários (para debug/visualização) ---

func get_center_of_pressure_ws(tire_transform: Transform3D) -> Vector3:
    """Converte o centro de pressão para world-space (apenas para debug)"""
    return tire_transform * center_of_pressure_local

func get_average_normal_ws(tire_transform: Transform3D) -> Vector3:
    """Converte a normal média para world-space (apenas para debug)"""
    return tire_transform.basis * average_normal_local

func get_average_slip_magnitude() -> float:
    """Retorna a magnitude do slip médio (RAW, sem lag)"""
    return average_slip_local.length()

func get_lagged_slip_magnitude() -> float:
    """Retorna a magnitude do slip com micro-lag (para feeling)"""
    return lagged_slip_local.length()

func get_average_slip_direction() -> Vector2:
    """Retorna a direção normalizada do slip médio"""
    return average_slip_local.normalized() if average_slip_local.length_squared() > 0.0 else Vector2.ZERO

func get_lagged_slip_direction() -> Vector2:
    """Retorna a direção normalizada do slip com lag"""
    return lagged_slip_local.normalized() if lagged_slip_local.length_squared() > 0.0 else Vector2.ZERO

func get_hysteresis_debug_info() -> Dictionary:
    """Informações detalhadas da histerese para debug"""
    return {
        "stored_energy": stored_energy,
        "residual_energy": residual_energy,
        "hysteresis_factor": hysteresis_factor,
        "last_slip_mag": last_slip_magnitude,
        "lagged_slip_mag": get_lagged_slip_magnitude(),
        # Para debug apenas - não usar no solver
        "debug_effective": get_effective_grip_factor()
    }

# --- Propriedades computadas (conveniência) ---

func get_active_samples() -> Array[TireSample]:
    """Retorna apenas as amostras que contribuíram para o patch"""
    var active_samples: Array[TireSample] = []
    for sample in samples:
        if sample.valid and sample.penetration > 0.0:
            active_samples.append(sample)
    return active_samples

func get_sample_count() -> int:
    """Número total de amostras"""
    return samples.size()

func is_valid() -> bool:
    """Patch contém dados válidos para cálculos físicos"""
    return valid and contributing_samples > 0

func get_timestamp() -> float:
    """Timestamp da última atualização"""
    return timestamp

# --- Métodos para integração com solver ---

func get_effective_grip_factor() -> float:
    """
    Retorna fator de grip combinando histerese e confiança.
    Superfície ruim não só tem menos grip, mas se recupera pior.
    
     Combinação final dos efeitos de histerese:
    1. Histerese simples (stored_energy → hysteresis_factor)
    2. Memória residual (residual_energy)
    3. Modulação por confiança da superfície
    """
    # Confiança mapeada para [0.5, 1.0] - mesmo superfície ruim tem alguma recuperação
    var confidence_factor = lerp(CONFIDENCE_HYSTERESIS_MULTIPLIER, 1.0, patch_confidence)
    return hysteresis_factor * confidence_factor

func get_grip_modulation_factors() -> Dictionary:
    """
    Retorna fatores separados para o solver combinar apropriadamente.
    AVISO: O solver deve escolher entre usar get_effective_grip_factor() ou combinar manualmente.
    
     Contém ambos os componentes da histerese:
    1. stored_energy (histerese simples)
    2. residual_energy (memória residual)
    """
    return {
        "hysteresis": hysteresis_factor,
        "confidence": patch_confidence,
        "confidence_factor": lerp(CONFIDENCE_HYSTERESIS_MULTIPLIER, 1.0, patch_confidence),
        "effective": get_effective_grip_factor(),
        "lagged_slip": lagged_slip_local,  # Para sensação de massa
        "stored_energy": stored_energy,    #  Histerese simples
        "residual_energy": residual_energy #  Memória residual
    }

func get_thermal_state() -> float:
    """
    Estado térmico normalizado [0..1] baseado na histerese
    0 = frio, 1 = superaquecido (apenas unidades abstratas)
    
     Representação direta da histerese simples
    """
    return clamp(stored_energy / MAX_STORED_ENERGY, 0.0, 1.0)

# --- Representação para debug ---

func _to_string() -> String:
    return "ContactPatch(valid=%s, samples=%d/%d, conf=%.2f, hyst=%.2f, eff=%.2f, E=%.2f/%.2f)" % [
        valid, 
        contributing_samples, 
        samples.size(),
        patch_confidence,
        hysteresis_factor,
        get_effective_grip_factor(),
        stored_energy,      #  Histerese simples
        residual_energy     #  Memória residual
    ]

func get_debug_info() -> Dictionary:
    """Informações detalhadas para debug"""
    var factors = get_grip_modulation_factors()
    
    return {
        "valid": valid,
        "timestamp": timestamp,
        "samples_total": samples.size(),
        "samples_contributing": contributing_samples,
        "center_local": center_of_pressure_local,
        "normal_local": average_normal_local,
        "slip_raw": average_slip_local,
        "slip_lagged": lagged_slip_local,
        "slip_raw_mag": get_average_slip_magnitude(),
        "slip_lag_mag": get_lagged_slip_magnitude(),
        "total_weight": total_contact_weight,
        "max_penetration": max_penetration,
        "confidence": patch_confidence,
        "hysteresis": get_hysteresis_debug_info(),
        "grip_factors": factors,
        "thermal_state": get_thermal_state(),
        #  Destaque para os dois componentes principais
        "hysteresis_simple": {
            "stored_energy": stored_energy,
            "recovery_rate": HYSTERESIS_RECOVERY_SLOW if stored_energy > ENERGY_THRESHOLD else HYSTERESIS_RECOVERY_FAST,
            "factor": hysteresis_factor
        },
        "residual_memory": {
            "energy": residual_energy,
            "decay_rate": RESIDUAL_DECAY_RATE,
            "directional_noise": (residual_energy / MAX_STORED_ENERGY) * RESIDUAL_DIRECTIONAL_NOISE
        }
    }