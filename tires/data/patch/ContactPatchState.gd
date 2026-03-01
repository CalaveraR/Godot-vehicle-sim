# res://core/data/patch/ContactPatchState.gd
class_name ContactPatchState
extends RefCounted

# ==============================================================================
#   ContactPatchState – Estado/memória do patch de contato do pneu
#   Espaço local da roda + métricas agregadas + histerese temporal
#   ⚠️  Este NÃO é o patch em si, apenas seu estado (memória).
# ==============================================================================

# --- Constantes de histerese (unidades abstratas) ---
const MAX_STORED_ENERGY := 10.0
const MIN_HYSTERESIS_FACTOR := 0.7
const HYSTERESIS_RECOVERY_FAST := 4.0
const HYSTERESIS_RECOVERY_SLOW := 0.8
const RESIDUAL_DECAY_RATE := 2.0
const ENERGY_THRESHOLD := 5.0
const SLIP_ENERGY_THRESHOLD := 0.1

# --- Micro‑lag e ruído direcional (feeling) ---
const SLIP_LAG_RATE := 8.0
const RESIDUAL_DIRECTIONAL_NOISE := 0.05
const CONFIDENCE_HYSTERESIS_MULTIPLIER := 0.5

# --- Dados brutos ---
var samples: Array[TireSample] = []

# --- Agregados (espaço local da roda) ---
var center_of_pressure_local: Vector3
var average_normal_local: Vector3      # já normalizada
var average_slip_local: Vector2
var lagged_slip_local: Vector2        # slip com lag para sensação de massa

# --- Métricas escalares ---
var total_contact_weight: float
var max_penetration: float
var patch_confidence: float

# --- Estado de histerese ---
var stored_energy: float = 0.0        # energia acumulada (input)
var residual_energy: float = 0.0      # memória residual pós‑transição
var hysteresis_factor: float = 1.0    # [0.7 .. 1.0]
var last_slip_magnitude: float = 0.0

# --- Controle interno ---
var timestamp: float
var valid: bool = false
var contributing_samples: int = 0

# ------------------------------------------------------------------------------
#   Inicialização
# ------------------------------------------------------------------------------
func _init(sample_array: Array[TireSample] = [], time: float = 0.0) -> void:
    """
    Construtor opcional.
    Se fornecido, reconstrói o estado a partir das amostras.
    """
    rebuild_from_samples(sample_array, time)

# ------------------------------------------------------------------------------
#   Métodos públicos principais
# ------------------------------------------------------------------------------
func rebuild_from_samples(new_samples: Array[TireSample], time: float) -> void:
    """Substitui as amostras e recalcula todos os agregados."""
    samples = new_samples
    timestamp = time
    _recalculate_aggregates()
    lagged_slip_local = average_slip_local

func recalculate() -> void:
    """Recalcula agregados com as amostras atuais (útil após modificar amostras)."""
    _recalculate_aggregates()

func update_hysteresis(delta: float, tire_load: float, tire_stiffness: float) -> void:
    """
    Atualiza o estado de histerese com base no contato atual.
    - delta: tempo desde a última atualização
    - tire_load: carga vertical no pneu
    - tire_stiffness: rigidez vertical do pneu
    """
    if not valid:
        stored_energy *= exp(-HYSTERESIS_RECOVERY_FAST * delta)
        residual_energy *= exp(-RESIDUAL_DECAY_RATE * delta)
        _update_hysteresis_factor()
        return

    var current_slip_mag = get_average_slip_magnitude()

    # --- Acúmulo de energia (input) ---
    if current_slip_mag > SLIP_ENERGY_THRESHOLD:
        stored_energy += current_slip_mag * tire_load * delta
    if max_penetration > 0.0:
        stored_energy += max_penetration * tire_stiffness * delta

    # --- Memória residual para transições bruscas ---
    var slip_change = abs(current_slip_mag - last_slip_magnitude)
    if slip_change > 0.2:
        residual_energy += slip_change * tire_load * 0.5

    stored_energy = min(stored_energy, MAX_STORED_ENERGY)

    # --- Recuperação (decay exponencial) ---
    var decay_rate = HYSTERESIS_RECOVERY_SLOW if stored_energy > ENERGY_THRESHOLD else HYSTERESIS_RECOVERY_FAST
    stored_energy *= exp(-decay_rate * delta)
    residual_energy *= exp(-RESIDUAL_DECAY_RATE * delta)

    # --- Efeitos de feeling ---
    _apply_slip_lag(delta)
    _apply_directional_noise()
    _update_hysteresis_factor()

    last_slip_magnitude = current_slip_mag

func reset_hysteresis() -> void:
    """
    Reseta APENAS o estado de histerese (energias, fator, lag).
    Chamar exclusivamente em teleporte explícito para evitar popping.
    """
    stored_energy = 0.0
    residual_energy = 0.0
    hysteresis_factor = 1.0
    last_slip_magnitude = 0.0
    lagged_slip_local = average_slip_local

func reset() -> void:
    """
    Reseta os dados do patch (amostras e agregados), mas PRESERVA a histerese.
    Útil para pooling de objetos.
    """
    samples.clear()
    timestamp = 0.0
    _reset_to_default()

func reset_all() -> void:
    """
    Reseta COMPLETAMENTE o estado: dados do patch + histerese.
    Equivalente a reset() + reset_hysteresis().
    """
    reset()
    reset_hysteresis()

# ------------------------------------------------------------------------------
#   Método de compatibilidade com a versão anterior (ContactPatch)
# ------------------------------------------------------------------------------
func update_from_patch(patch: ContactPatch, delta: float, tire_load: float, tire_stiffness: float) -> void:
    """
    🔁 Método legado – atualiza o estado a partir de um objeto ContactPatch.
    Extrai as amostras do patch, reconstrói agregados e aplica histerese.
    """
    # Assumindo que ContactPatch expõe suas amostras via método get_samples() ou variável 'samples'
    var patch_samples = patch.samples if "samples" in patch else []
    rebuild_from_samples(patch_samples, Time.get_ticks_usec() / 1_000_000.0)
    update_hysteresis(delta, tire_load, tire_stiffness)

# ------------------------------------------------------------------------------
#   Cálculo interno dos agregados
# ------------------------------------------------------------------------------
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

    for sample in samples:
        if not sample.valid or sample.penetration <= 0.0:
            continue

        var weight = sample.penetration * sample.confidence
        if weight <= 0.0:
            continue

        weighted_pos += sample.contact_pos_local * weight
        weighted_normal += sample.contact_normal_local * weight
        weighted_slip += sample.slip_vector * weight

        total_contact_weight += weight
        max_penetration = max(max_penetration, sample.penetration)
        patch_confidence += sample.confidence
        contributing_samples += 1

    if total_contact_weight <= 0.0 or contributing_samples == 0:
        _reset_to_default()
        return

    center_of_pressure_local = weighted_pos / total_contact_weight
    average_normal_local = (weighted_normal / total_contact_weight).normalized()
    average_slip_local = weighted_slip / total_contact_weight
    patch_confidence /= float(contributing_samples)
    valid = true

func _reset_to_default() -> void:
    """Valores padrão para quando não há contato válido."""
    center_of_pressure_local = Vector3.ZERO
    average_normal_local = Vector3.UP
    average_slip_local = Vector2.ZERO
    lagged_slip_local = Vector2.ZERO
    total_contact_weight = 0.0
    max_penetration = 0.0
    patch_confidence = 0.0
    contributing_samples = 0
    valid = false
    # NOTA: histerese NÃO é resetada aqui (mantida entre frames)

# ------------------------------------------------------------------------------
#   Efeitos de feeling (micro‑lag e ruído)
# ------------------------------------------------------------------------------
func _apply_slip_lag(delta: float) -> void:
    if valid and average_slip_local.length_squared() > 0.0:
        var lag_weight = exp(-SLIP_LAG_RATE * delta)
        lagged_slip_local = lagged_slip_local.lerp(average_slip_local, lag_weight)
    else:
        lagged_slip_local = average_slip_local

func _apply_directional_noise() -> void:
    if valid and residual_energy > 0.0 and lagged_slip_local.length_squared() > 0.0:
        var noise_scale = (residual_energy / MAX_STORED_ENERGY) * RESIDUAL_DIRECTIONAL_NOISE
        var orthogonal = lagged_slip_local.orthogonal() * noise_scale
        lagged_slip_local += orthogonal

func _update_hysteresis_factor() -> void:
    var total_energy = stored_energy + residual_energy * 0.3
    var norm_energy = clamp(total_energy / MAX_STORED_ENERGY, 0.0, 1.0)
    hysteresis_factor = lerp(1.0, MIN_HYSTERESIS_FACTOR, sqrt(norm_energy))

# ------------------------------------------------------------------------------
#   Getters utilitários (para debug / visualização)
# ------------------------------------------------------------------------------
func get_center_of_pressure_ws(tire_transform: Transform3D) -> Vector3:
    return tire_transform * center_of_pressure_local

func get_average_normal_ws(tire_transform: Transform3D) -> Vector3:
    return tire_transform.basis * average_normal_local

func get_average_slip_magnitude() -> float:
    return average_slip_local.length()

func get_lagged_slip_magnitude() -> float:
    return lagged_slip_local.length()

func get_average_slip_direction() -> Vector2:
    return average_slip_local.normalized() if average_slip_local.length_squared() > 0.0 else Vector2.ZERO

func get_lagged_slip_direction() -> Vector2:
    return lagged_slip_local.normalized() if lagged_slip_local.length_squared() > 0.0 else Vector2.ZERO

func get_hysteresis_debug_info() -> Dictionary:
    return {
        "stored_energy": stored_energy,
        "residual_energy": residual_energy,
        "hysteresis_factor": hysteresis_factor,
        "last_slip_mag": last_slip_magnitude,
        "lagged_slip_mag": get_lagged_slip_magnitude(),
        "debug_effective": get_effective_grip_factor()
    }

func get_active_samples() -> Array[TireSample]:
    var active: Array[TireSample] = []
    for s in samples:
        if s.valid and s.penetration > 0.0:
            active.append(s)
    return active

func get_sample_count() -> int:
    return samples.size()

func is_valid() -> bool:
    return valid and contributing_samples > 0

func get_timestamp() -> float:
    return timestamp

# ------------------------------------------------------------------------------
#   Integração com solver / fatores de grip
# ------------------------------------------------------------------------------
func get_effective_grip_factor() -> float:
    var confidence_factor = lerp(CONFIDENCE_HYSTERESIS_MULTIPLIER, 1.0, patch_confidence)
    return hysteresis_factor * confidence_factor

func get_grip_modulation_factors() -> Dictionary:
    return {
        "hysteresis": hysteresis_factor,
        "confidence": patch_confidence,
        "confidence_factor": lerp(CONFIDENCE_HYSTERESIS_MULTIPLIER, 1.0, patch_confidence),
        "effective": get_effective_grip_factor(),
        "lagged_slip": lagged_slip_local,
        "stored_energy": stored_energy,
        "residual_energy": residual_energy
    }

func get_thermal_state() -> float:
    return clamp(stored_energy / MAX_STORED_ENERGY, 0.0, 1.0)

# ------------------------------------------------------------------------------
#   Representação textual e debug
# ------------------------------------------------------------------------------
func _to_string() -> String:
    return "ContactPatchState(valid=%s, samples=%d/%d, conf=%.2f, hyst=%.2f, eff=%.2f, E=%.2f/%.2f)" % [
        valid,
        contributing_samples,
        samples.size(),
        patch_confidence,
        hysteresis_factor,
        get_effective_grip_factor(),
        stored_energy,
        residual_energy
    ]

func get_debug_info() -> Dictionary:
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
        "grip_factors": get_grip_modulation_factors(),
        "thermal_state": get_thermal_state(),
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