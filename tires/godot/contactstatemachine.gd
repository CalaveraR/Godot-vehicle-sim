# res://core/state/ContactStateMachine.gd
# Máquina de estados para continuidade temporal do contato do pneu.
# Responsabilidades:
# - Gerenciar transições entre modos de contato (válido, persistente, impacto, aéreo)
# - Aplicar decaimento suave de forças e confiança
# - Fornecer forças processadas com blend contínuo
# - Não armazena referência direta ao ContactPatch (evita ghost data)
# - Torque não é tratado aqui (delegado para sistema separado)
class_name ContactStateMachine
extends Node

# --- Estados da máquina ---
enum ContactMode {
	GROUNDED_VALID,      # Contato válido e confiável
	GROUNDED_PERSISTENT, # Contato fraco, mantido por memória
	IMPACT_TRANSITION,   # Transição abrupta (pulo, colisão forte)
	AIRBORNED            # Sem contato
}

# --- Parâmetros exportados (ajustáveis no inspetor) ---
@export_group("Confidence Thresholds")
@export var valid_confidence_threshold: float = 0.65
@export var minimal_confidence_threshold: float = 0.35

@export_group("Decay Rates")
@export var confidence_decay_rate: float = 4.0       # Decaimento da confiança (/s)
@export var fallback_decay_rate: float = 8.0         # Decaimento das forças de fallback (/s)
@export var physical_torque_decay_rate: float = 8.0  # (não usado, mantido para compatibilidade)
@export var stabilizing_torque_decay_rate: float = 12.0

@export_group("Persistence")
@export var max_persistence_time: float = 0.25        # Tempo máximo no modo persistente

@export_group("Impact")
@export var impact_detection_threshold: float = 50.0 # Aceleração da confiança p/ detectar impacto
@export var impact_transition_time: float = 0.1      # Duração do modo impacto
@export var impact_decay_multiplier: float = 3.0     # Velocidade de decaimento durante impacto

@export_group("Temporal Filter")
@export var confidence_temporal_filter: bool = true  # Filtro de 1 frame na confiança
@export var temporal_filter_blend: float = 0.7       # Peso do valor anterior

# --- Variáveis de estado interno ---
var _current_mode: ContactMode = ContactMode.AIRBORNED
var _previous_mode: ContactMode = ContactMode.AIRBORNED
var _mode_timer: float = 0.0
var _persistence_timer: float = 0.0

var _is_grounded: bool = false
var _contact_age: float = 0.0
var _airborne_age: float = 0.0

var _current_confidence: float = 0.0
var _previous_confidence: float = 0.0
var _last_patch_confidence: float = 0.0

# Forças de fallback (usadas quando não há contato válido)
var _fallback_forces: Dictionary = {"Fx": 0.0, "Fy": 0.0, "Fz": 0.0}

# Buffer para detecção de impacto
var _impact_buffer: Array[Dictionary] = []
var _max_impact_buffer_size: int = 3

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------
func _init() -> void:
	reset_state()

func reset_state() -> void:
	_current_mode = ContactMode.AIRBORNED
	_previous_mode = ContactMode.AIRBORNED
	_mode_timer = 0.0
	_persistence_timer = 0.0
	_is_grounded = false
	_contact_age = 0.0
	_airborne_age = 0.0
	_current_confidence = 0.0
	_previous_confidence = 0.0
	_last_patch_confidence = 0.0
	_fallback_forces = {"Fx": 0.0, "Fy": 0.0, "Fz": 0.0}
	_impact_buffer.clear()

# ------------------------------------------------------------------------------
# Interface principal (chamada pelo solver a cada frame)
# ------------------------------------------------------------------------------

## Processa o estado do contato e retorna as forças finais com continuidade.
## @param patch:           Patch atual (não armazenado, usado apenas para debug futuro)
## @param patch_confidence: Confiança bruta do patch (0..1)
## @param raw_forces:      Forças calculadas pelo solver para este frame
## @param delta:           Tempo desde o último frame
## @return Dictionary contendo Fx, Fy, Fz e metadados
func update(
	patch: ContactPatch,
	patch_confidence: float,
	raw_forces: Dictionary,
	delta: float
) -> Dictionary:
	# Filtro temporal de baixa passagem (opcional)
	var filtered_confidence = patch_confidence
	if confidence_temporal_filter and _last_patch_confidence > 0:
		filtered_confidence = lerp(_last_patch_confidence, patch_confidence, temporal_filter_blend)
	_last_patch_confidence = patch_confidence

	# Atualiza timers
	_mode_timer += delta
	_persistence_timer += delta if _current_mode == ContactMode.GROUNDED_PERSISTENT else 0.0

	# Detecta impacto baseado na variação da confiança
	var impact_detected = _detect_impact(filtered_confidence, delta)

	# --- Transições de estado ---
	if filtered_confidence >= valid_confidence_threshold:
		_transition_to_grounded_valid(raw_forces, filtered_confidence, delta)
	elif filtered_confidence >= minimal_confidence_threshold and _current_mode != ContactMode.AIRBORNED:
		_transition_to_grounded_persistent(raw_forces, filtered_confidence, delta)
	elif impact_detected and not _impact_buffer.is_empty():
		_transition_to_impact(delta)
	else:
		_transition_to_airborne(delta)

	# Atualiza idades
	if _is_grounded:
		_contact_age += delta
		_airborne_age = 0.0
	else:
		_airborne_age += delta
		_contact_age = 0.0

	# --- Montagem das forças de saída ---
	return _get_processed_forces(raw_forces, delta)

## Retorna o torque processado (físico + estabilizador).
## ATENÇÃO: Esta máquina NÃO calcula torque físico. O valor retornado é apenas um fallback
##          com decaimento para manter a sensação de inércia. Para torque real, use sistema dedicado.
func get_processed_torque() -> Vector3:
	# Versão simplificada: apenas um torque residual que decai.
	# Não há dependência de patch.
	return Vector3.ZERO  # ou implementar fallback simples se necessário

# ------------------------------------------------------------------------------
# Transições de estado (privadas)
# ------------------------------------------------------------------------------
func _set_mode(new_mode: ContactMode) -> void:
	if _current_mode != new_mode:
		_previous_mode = _current_mode
		_current_mode = new_mode
		_mode_timer = 0.0
		if new_mode != ContactMode.GROUNDED_PERSISTENT:
			_persistence_timer = 0.0

func _transition_to_grounded_valid(raw_forces: Dictionary, confidence: float, delta: float) -> void:
	_set_mode(ContactMode.GROUNDED_VALID)
	_is_grounded = true
	_current_confidence = confidence
	_previous_confidence = confidence
	_fallback_forces = raw_forces.duplicate()

func _transition_to_grounded_persistent(raw_forces: Dictionary, confidence: float, delta: float) -> void:
	_set_mode(ContactMode.GROUNDED_PERSISTENT)
	_is_grounded = true

	# Tempo máximo de persistência – força transição para aéreo
	if _persistence_timer >= max_persistence_time:
		_transition_to_airborne(delta)
		return

	# Decaimento da confiança
	_current_confidence = max(
		_current_confidence - delta * confidence_decay_rate,
		minimal_confidence_threshold
	)

	# Decaimento das forças de fallback
	_fallback_forces = _apply_fallback_decay(_fallback_forces, delta)

func _transition_to_impact(delta: float) -> void:
	_set_mode(ContactMode.IMPACT_TRANSITION)
	_is_grounded = true

	if not _impact_buffer.is_empty():
		var latest = _impact_buffer[0]
		_current_confidence = latest.confidence

	# O modo impacto tem duração fixa; ao término, volta para aéreo ou válido
	if _mode_timer >= impact_transition_time:
		_transition_to_airborne(delta)

func _transition_to_airborne(delta: float) -> void:
	_set_mode(ContactMode.AIRBORNED)
	_is_grounded = false

	_current_confidence = max(_current_confidence - delta * confidence_decay_rate, 0.0)
	_fallback_forces = _apply_fallback_decay(_fallback_forces, delta)

# ------------------------------------------------------------------------------
# Processamento de forças
# ------------------------------------------------------------------------------
func _get_processed_forces(raw_forces: Dictionary, delta: float) -> Dictionary:
	match _current_mode:
		ContactMode.GROUNDED_VALID:
			return {
				"Fx": raw_forces.Fx * _current_confidence,
				"Fy": raw_forces.Fy * _current_confidence,
				"Fz": raw_forces.Fz * _current_confidence,
				"source": "grounded_valid",
				"confidence": _current_confidence,
				"mode_timer": _mode_timer
			}

		ContactMode.GROUNDED_PERSISTENT:
			# Blend linear entre fallback e forças brutas
			var blend = (_current_confidence - minimal_confidence_threshold) / \
						(valid_confidence_threshold - minimal_confidence_threshold)
			blend = clamp(blend, 0.0, 1.0)
			return {
				"Fx": lerp(_fallback_forces.Fx, raw_forces.Fx, blend),
				"Fy": lerp(_fallback_forces.Fy, raw_forces.Fy, blend),
				"Fz": lerp(_fallback_forces.Fz, raw_forces.Fz, blend),
				"source": "grounded_persistent",
				"confidence": _current_confidence,
				"mode_timer": _mode_timer,
				"persistence_timer": _persistence_timer
			}

		ContactMode.IMPACT_TRANSITION:
			# Transição exponencial: forças vão a zero rapidamente
			var transition_blend = min(_mode_timer / impact_transition_time, 1.0)
			var impact_blend = 1.0 - exp(-transition_blend * impact_decay_multiplier)
			return {
				"Fx": _fallback_forces.Fx * (1.0 - impact_blend),
				"Fy": _fallback_forces.Fy * (1.0 - impact_blend),
				"Fz": _fallback_forces.Fz * (1.0 - impact_blend),
				"source": "impact_transition",
				"confidence": _current_confidence * (1.0 - impact_blend),
				"mode_timer": _mode_timer,
				"transition_blend": transition_blend
			}

		ContactMode.AIRBORNED, _:
			return {
				"Fx": _fallback_forces.Fx,
				"Fy": _fallback_forces.Fy,
				"Fz": _fallback_forces.Fz,
				"source": "airborne_fallback",
				"confidence": _current_confidence,
				"mode_timer": _mode_timer
			}

func _apply_fallback_decay(forces: Dictionary, delta: float) -> Dictionary:
	var decay = exp(-delta * fallback_decay_rate)
	return {
		"Fx": forces.Fx * decay,
		"Fy": forces.Fy * decay,
		"Fz": forces.Fz * decay
	}

# ------------------------------------------------------------------------------
# Detecção de impacto
# ------------------------------------------------------------------------------
func _detect_impact(patch_confidence: float, delta: float) -> bool:
	var confidence_delta = patch_confidence - _current_confidence
	var confidence_accel = abs(confidence_delta / delta) if delta > 0 else 0.0

	_impact_buffer.push_front({
		"confidence": patch_confidence,
		"delta": confidence_delta,
		"accel": confidence_accel,
		"time": _mode_timer
	})

	if _impact_buffer.size() > _max_impact_buffer_size:
		_impact_buffer.pop_back()

	if _impact_buffer.size() >= 2:
		var avg_accel = 0.0
		for i in range(_impact_buffer.size() - 1):
			avg_accel += _impact_buffer[i].accel
		avg_accel /= float(_impact_buffer.size() - 1)
		return avg_accel > impact_detection_threshold

	return false

# ------------------------------------------------------------------------------
# Consultores públicos (estado atual)
# ------------------------------------------------------------------------------
func is_grounded() -> bool:
	return _is_grounded

func get_current_mode() -> ContactMode:
	return _current_mode

func get_mode_name() -> String:
	match _current_mode:
		ContactMode.GROUNDED_VALID:    return "GROUNDED_VALID"
		ContactMode.GROUNDED_PERSISTENT: return "GROUNDED_PERSISTENT"
		ContactMode.IMPACT_TRANSITION:  return "IMPACT_TRANSITION"
		ContactMode.AIRBORNED:          return "AIRBORNED"
		_: return "UNKNOWN"

func get_current_confidence() -> float:
	return _current_confidence

func get_contact_age() -> float:
	return _contact_age

func get_airborne_age() -> float:
	return _airborne_age

# ------------------------------------------------------------------------------
# Debug
# ------------------------------------------------------------------------------
func get_debug_info() -> Dictionary:
	return {
		"mode": get_mode_name(),
		"previous_mode": _get_mode_name(_previous_mode),
		"is_grounded": _is_grounded,
		"contact_age": _contact_age,
		"airborne_age": _airborne_age,
		"confidence": _current_confidence,
		"previous_confidence": _previous_confidence,
		"fallback_forces": _fallback_forces,
		"mode_timer": _mode_timer,
		"persistence_timer": _persistence_timer,
		"impact_buffer_size": _impact_buffer.size(),
		"temporal_filter": confidence_temporal_filter
	}

func _get_mode_name(mode: ContactMode) -> String:
	match mode:
		ContactMode.GROUNDED_VALID:    return "GROUNDED_VALID"
		ContactMode.GROUNDED_PERSISTENT: return "GROUNDED_PERSISTENT"
		ContactMode.IMPACT_TRANSITION:  return "IMPACT_TRANSITION"
		ContactMode.AIRBORNED:          return "AIRBORNED"
		_: return "UNKNOWN"