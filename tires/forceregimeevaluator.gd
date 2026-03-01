# res://core/logic/ForceRegimeEvaluator.gd
# =============================================================================
# AVALIADOR DE REGIME DE FORÇA – UNIFICADO E REUTILIZÁVEL
# =============================================================================
# Extraído e consolidado a partir de:
#   - TireContactSolver
#   - TireForceRegimeController
#
# Responsabilidade única: decidir o regime de operação (STANDARD, DEGRADED,
# FALLBACK) baseado em energia armazenada, confiança, persistência de slip e
# histerese. Não calcula forças nem gerencia modelos físicos.
# =============================================================================
class_name ForceRegimeEvaluator
extends RefCounted

# -----------------------------------------------------------------------------
# ENUMS
# -----------------------------------------------------------------------------
enum ForceRegime { STANDARD, DEGRADED, FALLBACK }

# -----------------------------------------------------------------------------
# CONFIGURAÇÃO (valores normalizados 0..1, exceto onde indicado)
# -----------------------------------------------------------------------------
var fallback_to_degraded_energy : float = 0.5   # Energia mínima para sair de FALLBACK
var degraded_to_standard_energy : float = 0.3   # Energia máxima para subir para STANDARD
var regime_hysteresis           : float = 0.05  # Banda morta para evitar oscilações
var min_regime_persistence      : float = 0.1   # segundos mínimos no regime atual
var slip_persistence_factor     : float = 0.5   # peso da persistência do slip
var confidence_high_threshold   : float = 0.7   # confiança necessária para STANDARD
var confidence_low_threshold    : float = 0.3   # abaixo disso força FALLBACK
var confidence_degraded_threshold : float = 0.5 # confiança que pode rebaixar para DEGRADED

# -----------------------------------------------------------------------------
# ESTADO INTERNO (histórico de slip para cálculo de persistência)
# -----------------------------------------------------------------------------
var _regime_slip_history : Array[Dictionary] = []
var _last_slip_vector    : Vector2 = Vector2.ZERO

# -----------------------------------------------------------------------------
# DEBUG
# -----------------------------------------------------------------------------
var debug_mode           : bool = false
var log_regime_changes   : bool = true
var _transition_count    : int = 0

# -----------------------------------------------------------------------------
# INICIALIZAÇÃO E CONFIGURAÇÃO
# -----------------------------------------------------------------------------
func configure(config: Dictionary) -> void:
    """Aplica parâmetros de configuração (valores são clampados)."""
    if config.has("fallback_to_degraded_energy"):
        fallback_to_degraded_energy = clamp(config.fallback_to_degraded_energy, 0.0, 1.0)
    if config.has("degraded_to_standard_energy"):
        degraded_to_standard_energy = clamp(config.degraded_to_standard_energy, 0.0, 1.0)
    if config.has("regime_hysteresis"):
        regime_hysteresis = clamp(config.regime_hysteresis, 0.0, 0.2)
    if config.has("min_regime_persistence"):
        min_regime_persistence = max(0.0, config.min_regime_persistence)
    if config.has("slip_persistence_factor"):
        slip_persistence_factor = clamp(config.slip_persistence_factor, 0.0, 1.0)
    if config.has("confidence_high_threshold"):
        confidence_high_threshold = clamp(config.confidence_high_threshold, 0.0, 1.0)
    if config.has("confidence_low_threshold"):
        confidence_low_threshold = clamp(config.confidence_low_threshold, 0.0, 1.0)
    if config.has("confidence_degraded_threshold"):
        confidence_degraded_threshold = clamp(config.confidence_degraded_threshold, 0.0, 1.0)
    if config.has("debug_mode"):
        debug_mode = config.debug_mode
    if config.has("log_regime_changes"):
        log_regime_changes = config.log_regime_changes

# -----------------------------------------------------------------------------
# INTERFACE PÚBLICA PRINCIPAL
# -----------------------------------------------------------------------------
func evaluate(
    patch: ContactPatch,
    current_regime: ForceRegime,
    regime_persistence: float,
    delta: float
) -> Dictionary:
    """
    Avalia o patch e decide o novo regime.

    Parâmetros:
        patch                - Patch de contato atual (não nulo)
        current_regime       - Regime em vigor neste frame
        regime_persistence   - Tempo (s) desde a última mudança de regime
        delta                - Delta time do frame (não usado diretamente, mantido para compatibilidade)

    Retorna:
        Dicionário com:
            - regime        : ForceRegime (novo regime proposto)
            - changed       : bool        (true se houve transição)
            - reason        : String      (descrição legível)
            - slip_persistence : float    (valor calculado)
            - energy_factor : float       (energia normalizada do patch)
            - confidence    : float       (confiança do patch)
            - transition_count : int      (total de transições desde o início)
    """
    # Atualiza histórico de slip para persistência
    _update_regime_slip_history(patch.average_slip)

    # Se as transições estiverem desabilitadas globalmente, o regime externo deve permanecer
    # (aqui apenas calculamos, não armazenamos estado fixo)
    # O chamador decide se usa o resultado.

    # Persistência mínima do regime atual – se não foi atingida, mantém o atual
    if regime_persistence < min_regime_persistence:
        return _build_result(
            current_regime,
            false,
            "persistence_min_not_reached",
            _calculate_slip_persistence(),
            patch
        )

    var new_regime := current_regime
    var reason := "no_change"

    # Obtém dados normalizados do patch (API explícita do ContactPatch)
    var energy_norm := patch.get_thermal_state()          # 0..1
    var confidence   := patch.patch_confidence           # 0..1

    # Calcula persistência do slip e seu fator de influência
    var slip_persistence := _calculate_slip_persistence()
    var slip_factor := slip_persistence * slip_persistence_factor

    # --- LÓGICA DE TRANSIÇÃO (EMERGENTE) ------------------------------------
    match current_regime:
        ForceRegime.FALLBACK:
            # Sobe para DEGRADED se energia suficiente
            var required_energy = fallback_to_degraded_energy + slip_factor * 0.1
            if energy_norm > required_energy:
                new_regime = ForceRegime.DEGRADED
                reason = "energy_above_fallback_threshold"

        ForceRegime.DEGRADED:
            var max_energy_for_standard = degraded_to_standard_energy - slip_factor * 0.05

            # SOBE para STANDARD
            if energy_norm < max_energy_for_standard and confidence > confidence_high_threshold:
                new_regime = ForceRegime.STANDARD
                reason = "energy_low_and_confidence_high"

            # DESCE para FALLBACK
            elif energy_norm < fallback_to_degraded_energy - regime_hysteresis or confidence < confidence_low_threshold:
                new_regime = ForceRegime.FALLBACK
                reason = "energy_critical_or_confidence_low"

        ForceRegime.STANDARD:
            var min_energy_for_degraded = degraded_to_standard_energy + regime_hysteresis + slip_factor * 0.05

            # DESCE para DEGRADED
            if energy_norm > min_energy_for_degraded or confidence < confidence_degraded_threshold:
                new_regime = ForceRegime.DEGRADED
                reason = "energy_high_or_confidence_degraded"

    # --- REGISTRO DE TRANSIÇÃO ---------------------------------------------
    var changed := (new_regime != current_regime)
    if changed:
        _transition_count += 1
        _log_transition(current_regime, new_regime, reason, energy_norm, confidence, slip_persistence)

    return _build_result(
        new_regime,
        changed,
        reason,
        slip_persistence,
        patch
    )

# -----------------------------------------------------------------------------
# MÉTODOS AUXILIARES – HISTÓRICO DE SLIP
# -----------------------------------------------------------------------------
func _update_regime_slip_history(slip_vector: Vector2) -> void:
    """Adiciona o slip atual ao histórico e mantém os últimos 10 frames."""
    _last_slip_vector = slip_vector
    _regime_slip_history.append({
        "time": Time.get_ticks_msec() / 1000.0,
        "slip": slip_vector,
        "magnitude": slip_vector.length()
    })
    if _regime_slip_history.size() > 10:
        _regime_slip_history.remove_at(0)

func _calculate_slip_persistence() -> float:
    """
    Retorna um valor entre 0..1 que representa o quão constante
    e significativo é o deslizamento no histórico recente.
    """
    if _regime_slip_history.size() < 3:
        return 0.0

    var total_variation := 0.0
    var max_magnitude   := 0.0

    for i in range(1, _regime_slip_history.size()):
        var current := _regime_slip_history[i].slip
        var prev    := _regime_slip_history[i-1].slip
        total_variation += (current - prev).length()
        max_magnitude = max(max_magnitude, _regime_slip_history[i].magnitude)

    if max_magnitude < 0.1:
        return 0.0

    var avg_variation := total_variation / (_regime_slip_history.size() - 1)
    var slip_constant := 1.0 - clamp(avg_variation / max_magnitude, 0.0, 1.0)
    return slip_constant * max_magnitude

# -----------------------------------------------------------------------------
# MÉTODOS AUXILIARES – RESULTADO E LOG
# -----------------------------------------------------------------------------
func _build_result(
    regime: ForceRegime,
    changed: bool,
    reason: String,
    slip_persistence: float,
    patch: ContactPatch
) -> Dictionary:
    """Monta o dicionário de resultado com todas as informações relevantes."""
    return {
        "regime": regime,
        "regime_string": _regime_to_string(regime),
        "changed": changed,
        "reason": reason,
        "slip_persistence": slip_persistence,
        "energy_factor": patch.get_thermal_state(),
        "confidence": patch.patch_confidence,
        "transition_count": _transition_count
    }

func _log_transition(
    from_regime: ForceRegime,
    to_regime: ForceRegime,
    reason: String,
    energy: float,
    confidence: float,
    slip_persistence: float
) -> void:
    """Exibe mensagem de debug quando ocorre uma transição de regime."""
    if not (debug_mode and log_regime_changes):
        return

    var from_str := _regime_to_string(from_regime)
    var to_str   := _regime_to_string(to_regime)
    print("[ForceRegimeEvaluator] Transição: %s → %s (motivo: %s) | E=%.2f, C=%.2f, SlipP=%.2f" %
          [from_str, to_str, reason, energy, confidence, slip_persistence])

static func _regime_to_string(regime: ForceRegime) -> String:
    match regime:
        ForceRegime.STANDARD:  return "STANDARD"
        ForceRegime.DEGRADED:   return "DEGRADED"
        ForceRegime.FALLBACK:   return "FALLBACK"
        _:                      return "UNKNOWN"

# -----------------------------------------------------------------------------
# UTILITÁRIOS PÚBLICOS
# -----------------------------------------------------------------------------
func get_slip_history() -> Array[Dictionary]:
    """Retorna o histórico de slip (para debug/visualização)."""
    return _regime_slip_history.duplicate()

func get_transition_count() -> int:
    return _transition_count

func reset_history() -> void:
    """Limpa o histórico de slip e zera o contador de transições."""
    _regime_slip_history.clear()
    _last_slip_vector = Vector2.ZERO
    _transition_count = 0