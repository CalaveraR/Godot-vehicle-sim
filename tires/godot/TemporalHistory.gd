# res://core/data/temporal/TemporalHistory.gd
class_name TemporalHistory
extends RefCounted
# ------------------------------------------------------------------------------
# TemporalHistory - Armazenamento e análise de séries temporais de contato
#
# RESPONSABILIDADES:
#   - Manter histórico ordenado de frames temporais (TemporalFrame)
#   - Calcular métricas temporais puras: velocidades, consistências, estabilidade
#   - Fornecer análises agnósticas de física (apenas variação no tempo)
#   - Gerenciar validade do histórico (mínimo 2 frames)
#
# USO:
#   var history = TemporalHistory.new(30)  # máximo 30 frames
#   history.add_frame(0.05, Vector2.ZERO, 0.9, Vector3.UP, true, time)
#   var vel = history.get_penetration_velocity()
#   var cons = history.get_overall_temporal_consistency()
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# INNER CLASS: TemporalFrame
#   Frame atômico, semântica puramente observacional.
# ------------------------------------------------------------------------------
class TemporalFrame:
	var timestamp: float          # segundos (monotônico)
	var penetration: float        # profundidade de penetração/compressão (metros)
	var slip: Vector2            # vetor slip observado (plano tangente)
	var confidence: float        # confiança da medição [0,1]
	var normal: Vector3          # vetor normal da superfície (normalizado)
	var contact: bool            # verdadeiro se há contato ativo
	
	func _init(
		p_timestamp: float,
		p_penetration: float,
		p_slip: Vector2,
		p_confidence: float,
		p_normal: Vector3,
		p_contact: bool
	) -> void:
		timestamp = p_timestamp
		penetration = p_penetration
		slip = p_slip
		confidence = p_confidence
		normal = p_normal
		contact = p_contact
	
	func _to_string() -> String:
		return "TemporalFrame(t=%.3f, p=%.3f, s=%s, c=%.2f, n=%s, contact=%s)" % [
			timestamp,
			penetration,
			"(%s,%s)" % [snapped(slip.x, 0.001), snapped(slip.y, 0.001)],
			confidence,
			"(%s,%s,%s)" % [snapped(normal.x, 0.01), snapped(normal.y, 0.01), snapped(normal.z, 0.01)],
			contact
		]

# ------------------------------------------------------------------------------
# CONFIGURAÇÃO
# ------------------------------------------------------------------------------
var max_frames: int = 30 : set = set_max_frames

# Escalas de normalização para consistência (valores típicos, ajustáveis)
var penetration_variation_scale: float = 0.1      # 10 cm
var slip_variation_scale: float = 1.0            # 1 unidade de slip
var confidence_variation_scale: float = 0.5      # 50% de variação
var normal_angle_threshold_deg: float = 30.0     # ângulo máximo para consistência perfeita

# ------------------------------------------------------------------------------
# ESTADO INTERNO
# ------------------------------------------------------------------------------
var _frames: Array[TemporalFrame] = []
var _is_valid: bool = false
var _last_contact_duration: float = 0.0  # cache da última duração calculada

# ------------------------------------------------------------------------------
# INICIALIZAÇÃO
# ------------------------------------------------------------------------------
func _init(p_max_frames: int = 30) -> void:
	max_frames = max(p_max_frames, 2)  # mínimo de 2 frames para análise

# ------------------------------------------------------------------------------
# GETTERS / SETTERS PÚBLICOS
# ------------------------------------------------------------------------------
func set_max_frames(value: int) -> void:
	max_frames = max(value, 2)
	_trim_history()

func is_valid() -> bool:
	return _is_valid

func get_frame_count() -> int:
	return _frames.size()

func get_time_span() -> float:
	"""Janela temporal coberta pelo histórico (segundos)."""
	if _frames.size() < 2:
		return 0.0
	return _frames[0].timestamp - _frames[-1].timestamp

# ------------------------------------------------------------------------------
# MANIPULAÇÃO DO HISTÓRICO
# ------------------------------------------------------------------------------
func add_frame(
	penetration: float,
	slip: Vector2,
	confidence: float,
	normal: Vector3,
	contact: bool,
	time: float
) -> void:
	"""
	Adiciona um novo frame ao início do histórico.
	Timestamp deve ser monotônico crescente; frames fora de ordem são ignorados.
	"""
	if _frames.size() > 0 and time <= _frames[0].timestamp:
		return  # mantém coerência temporal
	
	var frame := TemporalFrame.new(time, penetration, slip, confidence, normal, contact)
	_frames.push_front(frame)
	_trim_history()
	_update_validity()
	_last_contact_duration = _calculate_contact_duration()  # atualiza cache

func reset() -> void:
	_frames.clear()
	_is_valid = false
	_last_contact_duration = 0.0

func clear_old_frames(min_timestamp: float) -> void:
	"""
	Remove frames com timestamp anterior ao valor especificado.
	Pode invalidar o histórico intencionalmente.
	"""
	var i := _frames.size() - 1
	while i >= 0:
		if _frames[i].timestamp < min_timestamp:
			_frames.remove_at(i)
		i -= 1
	_update_validity()
	_last_contact_duration = _calculate_contact_duration()

# ------------------------------------------------------------------------------
# MÉTRICAS TEMPORAIS PURAS (VELOCIDADES)
# ------------------------------------------------------------------------------
func get_penetration_velocity() -> float:
	"""Variação da penetração entre os dois frames mais recentes (m/s)."""
	if not _has_sufficient_frames(2):
		return 0.0
	var dt := _frames[0].timestamp - _frames[1].timestamp
	if dt <= 0.0:
		return 0.0
	return (_frames[0].penetration - _frames[1].penetration) / dt

func get_slip_velocity() -> Vector2:
	"""Variação do vetor slip (unidades/s)."""
	if not _has_sufficient_frames(2):
		return Vector2.ZERO
	var dt := _frames[0].timestamp - _frames[1].timestamp
	if dt <= 0.0:
		return Vector2.ZERO
	return (_frames[0].slip - _frames[1].slip) / dt

func get_confidence_velocity() -> float:
	"""Variação da confiança (1/s)."""
	if not _has_sufficient_frames(2):
		return 0.0
	var dt := _frames[0].timestamp - _frames[1].timestamp
	if dt <= 0.0:
		return 0.0
	return (_frames[0].confidence - _frames[1].confidence) / dt

func get_normal_angular_velocity() -> float:
	"""Velocidade angular da normal entre os dois frames mais recentes (graus/s)."""
	if not _has_sufficient_frames(2):
		return 0.0
	var dt := _frames[0].timestamp - _frames[1].timestamp
	if dt <= 0.0:
		return 0.0
	var angle_rad := _frames[0].normal.angle_to(_frames[1].normal)
	return rad_to_deg(angle_rad) / dt

# ------------------------------------------------------------------------------
# CONSISTÊNCIA TEMPORAL (0.0 = inconsistente, 1.0 = perfeitamente consistente)
# ------------------------------------------------------------------------------
func get_penetration_consistency() -> float:
	"""Consistência da penetração ao longo do histórico."""
	return _compute_scalar_consistency(
		func(a, b): return abs(a - b),
		func(f): return f.penetration,
		penetration_variation_scale
	)

func get_slip_consistency() -> float:
	"""Consistência da magnitude do slip (vetor)."""
	return _compute_scalar_consistency(
		func(a, b): return a.distance_to(b),
		func(f): return f.slip,
		slip_variation_scale
	)

func get_confidence_consistency() -> float:
	"""Consistência da confiança."""
	return _compute_scalar_consistency(
		func(a, b): return abs(a - b),
		func(f): return f.confidence,
		confidence_variation_scale
	)

func get_normal_consistency() -> float:
	"""
	Consistência da direção da normal.
	Usa produto escalar, mapeia [0,1] onde 1 = mesma direção.
	"""
	return _compute_angular_consistency(
		func(f): return f.normal,
		normal_angle_threshold_deg
	)

func get_overall_temporal_consistency() -> float:
	"""Média das consistências individuais."""
	if not _is_valid:
		return 0.0
	var metrics := [
		get_penetration_consistency(),
		get_slip_consistency(),
		get_confidence_consistency(),
		get_normal_consistency()
	]
	var sum := 0.0
	for m in metrics:
		sum += m
	return sum / float(metrics.size())

# ------------------------------------------------------------------------------
# MÉTRICAS AVANÇADAS DE CONSISTÊNCIA
# ------------------------------------------------------------------------------
func get_max_penetration_variation() -> float:
	"""Máxima variação absoluta de penetração entre frames consecutivos."""
	if not _has_sufficient_frames(2):
		return 0.0
	var max_var := 0.0
	for i in range(1, _frames.size()):
		var var_ = abs(_frames[i-1].penetration - _frames[i].penetration)
		max_var = max(max_var, var_)
	return max_var

func get_slip_vector_direction_consistency() -> float:
	"""
	Consistência da DIREÇÃO do vetor slip (ignorando magnitude).
	Retorna 1.0 para direção constante, 0.0 para direções opostas.
	Frames com slip zero são ignorados (considera‑se consistente).
	"""
	if not _has_sufficient_frames(2):
		return 1.0
	var total_sim := 0.0
	var valid := 0
	for i in range(1, _frames.size()):
		if _frames[i-1].slip.length_squared() == 0.0 or _frames[i].slip.length_squared() == 0.0:
			continue
		var d1 := _frames[i-1].slip.normalized()
		var d2 := _frames[i].slip.normalized()
		var sim := d1.dot(d2)
		total_sim += (sim + 1.0) * 0.5  # mapeia [-1,1] -> [0,1]
		valid += 1
	return total_sim / float(valid) if valid > 0 else 1.0

func get_normal_direction_consistency() -> float:
	"""
	Consistência da direção da normal ao longo do tempo.
	Semelhante a get_normal_consistency(), mas opera sobre todo o histórico.
	"""
	return _compute_angular_consistency(
		func(f): return f.normal,
		normal_angle_threshold_deg
	)

# ------------------------------------------------------------------------------
# ANÁLISE DE CONTATO E ESTABILIDADE
# ------------------------------------------------------------------------------
func get_contact_duration() -> float:
	"""Duração contínua do contato (segundos) a partir do frame mais recente."""
	if not _is_valid or not _frames[0].contact:
		return 0.0
	return _last_contact_duration

func get_contact_stability() -> Dictionary:
	"""
	Análise de estabilidade do contato baseada em:
	  - Consistência do estado de contato
	  - Variância da penetração
	  - Duração do contato
	Retorna dicionário com score e recomendações.
	"""
	if not _has_sufficient_frames(2):
		return {
			"stable": false,
			"score": 0.0,
			"contact_consistency": 0.0,
			"compression_consistency": 0.0,
			"recommendation": "insufficient_data"
		}
	
	# 1. Consistência do estado de contato
	var changes := 0
	for i in range(1, _frames.size()):
		if _frames[i-1].contact != _frames[i].contact:
			changes += 1
	var contact_consistency := 1.0 - clamp(float(changes) / float(_frames.size() - 1), 0.0, 1.0)
	
	# 2. Consistência da penetração (via variância normalizada)
	var values: Array[float] = []
	for f in _frames:
		values.append(f.penetration)
	var avg = _calculate_average(values)
	var var_ = _calculate_variance(values, avg)
	var compression_consistency := 1.0 - clamp(var_ * 4.0, 0.0, 1.0)  # normalização empírica
	
	# 3. Pontuação geral
	var stability_score := contact_consistency * 0.6 + compression_consistency * 0.4
	var is_stable := stability_score > 0.7 and _frames[0].contact
	
	var recommendation: String
	if is_stable:
		if contact_consistency > 0.9 and compression_consistency > 0.8:
			recommendation = "highly_stable"
		else:
			recommendation = "moderately_stable"
	else:
		if not _frames[0].contact:
			recommendation = "no_contact"
		elif contact_consistency < 0.5:
			recommendation = "unstable_contact"
		else:
			recommendation = "unstable_compression"
	
	return {
		"stable": is_stable,
		"score": stability_score,
		"contact_consistency": contact_consistency,
		"compression_consistency": compression_consistency,
		"avg_penetration": avg,
		"penetration_variance": var_,
		"contact_changes": changes,
		"sample_count": _frames.size(),
		"recommendation": recommendation
	}

func get_temporal_stability() -> float:
	"""
	Alias para get_overall_temporal_consistency().
	Fornece um valor único de estabilidade temporal.
	"""
	return get_overall_temporal_consistency()

# ------------------------------------------------------------------------------
# MÉTRICAS AGREGADAS
# ------------------------------------------------------------------------------
func get_average_penetration(window: int = -1) -> float:
	"""Média da penetração nos últimos `window` frames (todos se -1)."""
	if _frames.is_empty():
		return 0.0
	var count := _frames.size() if window < 0 else min(window, _frames.size())
	var sum := 0.0
	for i in range(count):
		sum += _frames[i].penetration
	return sum / float(count)

func get_penetration_variance(window: int = -1) -> float:
	"""Variância da penetração na janela especificada."""
	if _frames.size() < 2:
		return 0.0
	var count := _frames.size() if window < 0 else min(window, _frames.size())
	var values: Array[float] = []
	for i in range(count):
		values.append(_frames[i].penetration)
	var mean = _calculate_average(values)
	return _calculate_variance(values, mean)

# ------------------------------------------------------------------------------
# DEBUG E INFORMAÇÕES
# ------------------------------------------------------------------------------
func get_debug_info() -> Dictionary:
	"""Resumo das métricas atuais para depuração."""
	return {
		"valid": _is_valid,
		"frame_count": _frames.size(),
		"time_span": get_time_span(),
		"penetration_velocity": get_penetration_velocity(),
		"slip_velocity": get_slip_velocity(),
		"normal_angular_velocity": get_normal_angular_velocity(),
		"penetration_consistency": get_penetration_consistency(),
		"slip_consistency": get_slip_consistency(),
		"confidence_consistency": get_confidence_consistency(),
		"normal_consistency": get_normal_consistency(),
		"overall_consistency": get_overall_temporal_consistency(),
		"max_penetration_variation": get_max_penetration_variation(),
		"slip_direction_consistency": get_slip_vector_direction_consistency(),
		"contact_duration": get_contact_duration(),
		"contact_stability": get_contact_stability().score,
		"temporal_stability": get_temporal_stability()
	}

func get_frames_debug() -> Array[String]:
	"""Representação textual de todos os frames (para logs detalhados)."""
	var out: Array[String] = []
	for i in _frames.size():
		out.append("[%d] %s" % [i, _frames[i]])
	return out

func _to_string() -> String:
	return "TemporalHistory(valid=%s, frames=%d, span=%.3fs, consistency=%.2f)" % [
		_is_valid,
		_frames.size(),
		get_time_span(),
		get_overall_temporal_consistency()
	]

# ------------------------------------------------------------------------------
# MÉTODOS PRIVADOS AUXILIARES
# ------------------------------------------------------------------------------
func _trim_history() -> void:
	while _frames.size() > max_frames:
		_frames.pop_back()

func _update_validity() -> void:
	_is_valid = _frames.size() >= 2

func _has_sufficient_frames(required: int) -> bool:
	return _frames.size() >= required

func _compute_scalar_consistency(
	diff_func: Callable,
	value_func: Callable,
	norm_scale: float
) -> float:
	"""Consistência média entre frames consecutivos para valores escalares ou vetoriais."""
	if not _has_sufficient_frames(2) or norm_scale <= 0.0:
		return 1.0  # sem evidência contrária, assume consistente
	var total := 0.0
	var count := 0
	for i in range(1, _frames.size()):
		var v1 = value_func.call(_frames[i-1])
		var v2 = value_func.call(_frames[i])
		var diff = diff_func.call(v1, v2)
		var ndiff := diff / norm_scale
		total += 1.0 - clamp(ndiff, 0.0, 1.0)
		count += 1
	return total / float(count) if count > 0 else 1.0

func _compute_angular_consistency(
	value_func: Callable,
	max_angle_deg: float
) -> float:
	"""
	Consistência angular baseada no produto escalar.
	Mapeia ângulo zero -> 1.0, ângulo >= max_angle_deg -> 0.0.
	"""
	if not _has_sufficient_frames(2) or max_angle_deg <= 0.0:
		return 1.0
	var total := 0.0
	var count := 0
	for i in range(1, _frames.size()):
		var v1 = value_func.call(_frames[i-1])
		var v2 = value_func.call(_frames[i])
		var dot = v1.dot(v2)
		var angle_deg = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
		var consistency := 1.0 - clamp(angle_deg / max_angle_deg, 0.0, 1.0)
		total += consistency
		count += 1
	return total / float(count) if count > 0 else 1.0

func _calculate_contact_duration() -> float:
	"""Percorre o histórico de trás para frente somando intervalos enquanto contact == true."""
	if _frames.is_empty() or not _frames[0].contact:
		return 0.0
	var dur := 0.0
	for i in range(1, _frames.size()):
		if not _frames[i].contact:
			break
		dur += _frames[i-1].timestamp - _frames[i].timestamp
	return dur

func _calculate_average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += v
	return sum / values.size()

func _calculate_variance(values: Array[float], mean: float) -> float:
	if values.size() < 2:
		return 0.0
	var sq_sum := 0.0
	for v in values:
		sq_sum += (v - mean) * (v - mean)
	return sq_sum / values.size()