class_name TemporalDynamicsSystem
extends Node

# Sistema Temporal e de Eventos
# Responsabilidades:
# - Cálculo de velocidade de compressão e variação de normais
# - Detecção de eventos súbitos (sudden_impact_detected)
# - Histórico de contatos e compressão
# - Sugestão de tempo de resposta baseado em dinâmica
# - Pontuação de eventos (event_score)
#
# Conecta com:
# - raycast_anchor_base.gd (recebe sinais de contato e dados de raycasts)
# - physical_metrics_processor.gd (recebe métricas para análise temporal)
# - contract_debug_visualizer.gd (fornece dados de eventos para visualização)
# - raycast_anchor_hybrid_main.gd (orquestração principal)
#
# Configuração esperada:
# - Limiares para detecção de eventos súbitos
# - Janelas de tempo para cálculo de velocidades
# - Configurações de histórico e retenção de dados

# Enums para tipos de eventos temporais
enum TemporalEventType {
    EVENT_NONE,              # Sem evento
    EVENT_CONTACT_START,     # Início de contato
    EVENT_CONTACT_END,       # Fim de contato
    EVENT_IMPACT,            # Impacto súbito
    EVENT_SLIDE,             # Deslizamento
    EVENT_BOUNCE,            # Ricochete
    EVENT_STABILIZATION,     # Estabilização
    EVENT_UNSTABLE           # Perda de estabilidade
}

# Estrutura para armazenar um evento temporal
class TemporalEvent:
    var type: int = TemporalEventType.EVENT_NONE
    var timestamp: float = 0.0
    var intensity: float = 0.0  # 0.0 a 1.0
    var position: Vector3 = Vector3.ZERO
    var normal: Vector3 = Vector3.UP
    var velocity: Vector3 = Vector3.ZERO
    var compression: float = 0.0
    var stability_score: float = 0.0
    var confidence: float = 0.0
    var metadata: Dictionary = {}
    
    func _init(p_type: int, p_timestamp: float, p_intensity: float = 0.0):
        type = p_type
        timestamp = p_timestamp
        intensity = clamp(p_intensity, 0.0, 1.0)
    
    func to_dictionary() -> Dictionary:
        """Converte o evento para dicionário."""
        return {
            "type": type,
            "timestamp": timestamp,
            "intensity": intensity,
            "position": position,
            "normal": normal,
            "velocity": velocity,
            "compression": compression,
            "stability_score": stability_score,
            "confidence": confidence,
            "metadata": metadata.duplicate()
        }

# Estrutura para análise de séries temporais
class TimeSeriesAnalysis:
    var compression_history: Array[float] = []
    var normal_history: Array[Vector3] = []
    var contact_history: Array[bool] = []
    var timestamps: Array[float] = []
    var max_history_size: int = 100
    
    var compression_velocity: float = 0.0  # Unidades/s
    var normal_variation: float = 0.0      # Graus/s
    var contact_duration: float = 0.0      # Segundos
    var avg_compression: float = 0.0
    var compression_variance: float = 0.0
    
    func _init(history_size: int = 100):
        max_history_size = history_size
    
    func add_sample(compression: float, normal: Vector3, has_contact: bool, timestamp: float) -> void:
        """Adiciona uma amostra à série temporal."""
        compression_history.append(compression)
        normal_history.append(normal)
        contact_history.append(has_contact)
        timestamps.append(timestamp)
        
        # Manter histórico dentro do limite
        if compression_history.size() > max_history_size:
            compression_history.remove_at(0)
            normal_history.remove_at(0)
            contact_history.remove_at(0)
            timestamps.remove_at(0)
        
        # Recalcular métricas
        _recalculate_metrics()
    
    func _recalculate_metrics() -> void:
        """Recalcula todas as métricas da série temporal."""
        if compression_history.size() < 2:
            compression_velocity = 0.0
            normal_variation = 0.0
            avg_compression = compression_history[0] if compression_history.size() > 0 else 0.0
            compression_variance = 0.0
            return
        
        # Calcular velocidade de compressão (diferença/tempo)
        var last_idx: int = compression_history.size() - 1
        var time_diff: float = timestamps[last_idx] - timestamps[last_idx - 1]
        
        if time_diff > 0.0:
            compression_velocity = (compression_history[last_idx] - compression_history[last_idx - 1]) / time_diff
        else:
            compression_velocity = 0.0
        
        # Calcular variação de normais
        if normal_history.size() >= 2:
            var angle_diff: float = rad_to_deg(normal_history[last_idx].angle_to(normal_history[last_idx - 1]))
            normal_variation = angle_diff / time_diff if time_diff > 0.0 else 0.0
        else:
            normal_variation = 0.0
        
        # Calcular duração do contato
        contact_duration = _calculate_contact_duration()
        
        # Calcular média e variância da compressão
        avg_compression = _calculate_average(compression_history)
        compression_variance = _calculate_variance(compression_history, avg_compression)
    
    func _calculate_contact_duration() -> float:
        """Calcula duração contínua do contato."""
        if contact_history.is_empty() or not contact_history.back():
            return 0.0
        
        var duration: float = 0.0
        var last_contact_time: float = timestamps.back()
        
        # Percorrer de trás para frente até encontrar sem contato
        for i in range(contact_history.size() - 1, -1, -1):
            if not contact_history[i]:
                break
            if i > 0:
                duration += timestamps[i] - timestamps[i - 1]
        
        return duration
    
    func _calculate_average(values: Array[float]) -> float:
        """Calcula média de um array de floats."""
        if values.is_empty():
            return 0.0
        
        var sum: float = 0.0
        for value in values:
            sum += value
        
        return sum / values.size()
    
    func _calculate_variance(values: Array[float], mean: float) -> float:
        """Calcula variância de um array de floats."""
        if values.size() < 2:
            return 0.0
        
        var sum_sq_diff: float = 0.0
        for value in values:
            sum_sq_diff += (value - mean) * (value - mean)
        
        return sum_sq_diff / values.size()
    
    func get_summary() -> Dictionary:
        """Retorna resumo da análise de séries temporais."""
        return {
            "compression_velocity": compression_velocity,
            "normal_variation": normal_variation,
            "contact_duration": contact_duration,
            "avg_compression": avg_compression,
            "compression_variance": compression_variance,
            "sample_count": compression_history.size(),
            "has_contact": contact_history.back() if not contact_history.is_empty() else false,
            "current_compression": compression_history.back() if not compression_history.is_empty() else 0.0,
            "current_normal": normal_history.back() if not normal_history.is_empty() else Vector3.UP
        }

# Sistema principal de dinâmica temporal
signal temporal_event_detected(event: TemporalEvent)
signal sudden_impact_detected(intensity: float, position: Vector3)
signal normal_variation_exceeded(rate: float, threshold: float)
signal contact_duration_updated(duration: float)
signal response_time_suggested(time: float, reason: String)

var _time_series: TimeSeriesAnalysis
var _event_history: Array[TemporalEvent] = []
var _current_contact_state: bool = false
var _last_contact_change_time: float = 0.0
var _last_impact_time: float = 0.0
var _last_stable_time: float = 0.0
var _system_start_time: float = 0.0

@export_group("Event Detection Thresholds")
@export var impact_threshold: float = 5.0  # Unidades/s de variação de compressão
@export var normal_variation_threshold: float = 30.0  # Graus/s
@export var slide_threshold: float = 2.0  # Unidades/s de variação lateral
@export var bounce_threshold: float = 3.0  # Unidades/s de variação positiva após impacto

@export_group("Time Windows")
@export var impact_cooldown: float = 0.1  # Segundos entre detecções de impacto
@export var stabilization_time: float = 0.5  # Segundos para considerar estabilizado
@export var history_window: float = 2.0  # Segundos para manter histórico detalhado

@export_group("Response Time Settings")
@export var min_response_time: float = 0.01  # Segundos
@export var max_response_time: float = 0.5   # Segundos
@export var adaptive_response_enabled: bool = true

@export_group("Filtering")
@export var velocity_smoothing: float = 0.7
@export var event_intensity_smoothing: float = 0.8
@export var require_min_samples: int = 3

func _ready() -> void:
    """Inicializa o sistema de dinâmica temporal."""
    _system_start_time = Time.get_ticks_msec() / 1000.0
    _time_series = TimeSeriesAnalysis.new(int(history_window * 60))  # Estimativa de 60 FPS
    
    # Conectar sinais de outros componentes (serão conectados externamente)
    _setup_internal_connections()
    _validate_configuration()

func _setup_internal_connections() -> void:
    """Configura conexões internas de sinais."""
    # Estas conexões serão feitas externamente pelo controlador principal
    pass

func _validate_configuration() -> void:
    """Valida configuração do sistema."""
    assert(impact_threshold > 0.0, "Limiar de impacto deve ser positivo")
    assert(normal_variation_threshold > 0.0, "Limiar de variação de normal deve ser positivo")
    assert(impact_cooldown > 0.0, "Cooldown de impacto deve ser positivo")
    assert(stabilization_time > 0.0, "Tempo de estabilização deve ser positivo")
    assert(history_window > 0.0, "Janela de histórico deve ser positiva")
    assert(min_response_time > 0.0, "Tempo mínimo de resposta deve ser positivo")
    assert(max_response_time > min_response_time, "Tempo máximo deve ser maior que mínimo")

func update_temporal_analysis(raycast_data: Array[Dictionary], metrics_data: Dictionary = {}) -> Dictionary:
    """
    Atualiza análise temporal com novos dados.
    
    Args:
        raycast_data: Dados atuais dos raycasts
        metrics_data: Métricas físicas calculadas (opcional)
    
    Returns:
        Dicionário com análise temporal completa
    """
    var current_time: float = Time.get_ticks_msec() / 1000.0
    
    # Extrair dados relevantes dos raycasts
    var has_contact: bool = false
    var avg_compression: float = 0.0
    var avg_normal: Vector3 = Vector3.UP
    var contact_count: int = 0
    
    for ray in raycast_data:
        if ray.get("has_contact", false):
            has_contact = true
            avg_compression += ray.get("compression", 0.0)
            avg_normal += ray.get("normal", Vector3.UP)
            contact_count += 1
    
    if contact_count > 0:
        avg_compression /= contact_count
        avg_normal = avg_normal.normalized()
    
    # Atualizar série temporal
    _time_series.add_sample(avg_compression, avg_normal, has_contact, current_time)
    
    # Detectar eventos
    var events: Array[TemporalEvent] = _detect_events(current_time, has_contact, avg_compression, avg_normal, metrics_data)
    
    # Atualizar estado de contato
    _update_contact_state(has_contact, current_time)
    
    # Calcular sugestão de tempo de resposta
    var response_suggestion: Dictionary = _calculate_response_time_suggestion(current_time, events)
    
    # Calcular pontuação de evento
    var event_score: float = _calculate_event_score(events, current_time)
    
    # Construir resultado
    var analysis_result: Dictionary = {
        "timestamp": current_time,
        "has_contact": has_contact,
        "contact_duration": _time_series.contact_duration,
        "compression_velocity": _time_series.compression_velocity,
        "normal_variation": _time_series.normal_variation,
        "avg_compression": avg_compression,
        "event_count": events.size(),
        "event_score": event_score,
        "suggested_response_time": response_suggestion.time,
        "response_reason": response_suggestion.reason,
        "time_series_summary": _time_series.get_summary(),
        "current_events": events.map(func(e): return e.to_dictionary())
    }
    
    # Emitir sinais para eventos detectados
    for event in events:
        temporal_event_detected.emit(event)
        
        if event.type == TemporalEventType.EVENT_IMPACT:
            sudden_impact_detected.emit(event.intensity, event.position)
        
        if event.type == TemporalEventType.EVENT_SLIDE:
            normal_variation_exceeded.emit(_time_series.normal_variation, normal_variation_threshold)
    
    # Emitir sinal de duração de contato se mudou significativamente
    _emit_contact_duration_if_changed()
    
    return analysis_result

func detect_sudden_impact(compression_velocity: float, normal_variation: float, 
                          current_time: float, position: Vector3 = Vector3.ZERO) -> TemporalEvent:
    """
    Detecta impacto súbito baseado em velocidade de compressão e variação de normal.
    
    Returns:
        Evento de impacto se detectado, null caso contrário
    """
    # Verificar cooldown
    if current_time - _last_impact_time < impact_cooldown:
        return null
    
    # Verificar se excede limiares
    var is_impact: bool = false
    var intensity: float = 0.0
    
    if abs(compression_velocity) > impact_threshold:
        is_impact = true
        intensity = clamp(abs(compression_velocity) / (impact_threshold * 2), 0.0, 1.0)
    
    if normal_variation > normal_variation_threshold * 1.5:
        is_impact = true
        intensity = max(intensity, clamp(normal_variation / (normal_variation_threshold * 3), 0.0, 1.0))
    
    if not is_impact:
        return null
    
    # Criar evento de impacto
    _last_impact_time = current_time
    var event: TemporalEvent = TemporalEvent.new(TemporalEventType.EVENT_IMPACT, current_time, intensity)
    event.position = position
    event.velocity = Vector3(0.0, compression_velocity, 0.0)  # Assumindo compressão no eixo Y
    event.compression = _time_series.avg_compression if _time_series else 0.0
    event.confidence = clamp(intensity * 0.8, 0.1, 1.0)
    
    # Adicionar metadados
    event.metadata = {
        "compression_velocity": compression_velocity,
        "normal_variation": normal_variation,
        "threshold_exceeded_by": abs(compression_velocity) / impact_threshold
    }
    
    # Registrar no histórico
    _add_event_to_history(event)
    
    return event

func calculate_contact_stability(contact_history: Array[bool], compression_history: Array[float],
                                time_window: float = 1.0) -> Dictionary:
    """
    Calcula estabilidade do contato baseado em histórico.
    
    Args:
        contact_history: Array de estados de contato
        compression_history: Array de valores de compressão
        time_window: Janela de tempo para análise (segundos)
    
    Returns:
        Dicionário com métricas de estabilidade
    """
    if contact_history.size() < 2 or compression_history.size() < 2:
        return {
            "stable": false,
            "score": 0.0,
            "contact_consistency": 0.0,
            "compression_consistency": 0.0,
            "recommendation": "insufficient_data"
        }
    
    # Calcular consistência de contato
    var contact_changes: int = 0
    for i in range(1, contact_history.size()):
        if contact_history[i] != contact_history[i - 1]:
            contact_changes += 1
    
    var contact_consistency: float = 1.0 - clamp(float(contact_changes) / float(contact_history.size() - 1), 0.0, 1.0)
    
    # Calcular consistência de compressão (variância normalizada)
    var avg_compression: float = 0.0
    for c in compression_history:
        avg_compression += c
    avg_compression /= compression_history.size()
    
    var variance: float = 0.0
    for c in compression_history:
        variance += (c - avg_compression) * (c - avg_compression)
    variance /= compression_history.size()
    
    # Normalizar variância (assumindo compressão máxima de 1.0)
    var compression_consistency: float = 1.0 - clamp(variance * 4.0, 0.0, 1.0)
    
    # Calcular pontuação geral de estabilidade
    var stability_score: float = (contact_consistency * 0.6 + compression_consistency * 0.4)
    var is_stable: bool = stability_score > 0.7
    
    # Determinar recomendação
    var recommendation: String
    if is_stable:
        if contact_consistency > 0.9 and compression_consistency > 0.8:
            recommendation = "highly_stable"
        else:
            recommendation = "moderately_stable"
    else:
        if contact_consistency < 0.5:
            recommendation = "unstable_contact"
        else:
            recommendation = "unstable_compression"
    
    return {
        "stable": is_stable,
        "score": stability_score,
        "contact_consistency": contact_consistency,
        "compression_consistency": compression_consistency,
        "avg_compression": avg_compression,
        "compression_variance": variance,
        "contact_changes": contact_changes,
        "sample_count": compression_history.size(),
        "recommendation": recommendation
    }

func suggest_response_time(current_dynamics: Dictionary, events: Array[TemporalEvent] = []) -> float:
    """
    Sugere tempo de resposta baseado na dinâmica atual e eventos.
    
    Returns:
        Tempo de resposta sugerido em segundos
    """
    if not adaptive_response_enabled:
        return max_response_time
    
    var base_time: float = max_response_time
    
    # Ajustar baseado na velocidade de compressão
    if current_dynamics.has("compression_velocity"):
        var velocity: float = abs(current_dynamics.compression_velocity)
        if velocity > impact_threshold * 0.5:
            # Reduzir tempo de resposta para eventos rápidos
            base_time = lerp(min_response_time, max_response_time * 0.5, 
                           clamp(velocity / impact_threshold, 0.0, 1.0))
    
    # Ajustar baseado na variação de normal
    if current_dynamics.has("normal_variation"):
        var variation: float = current_dynamics.normal_variation
        if variation > normal_variation_threshold * 0.3:
            base_time = min(base_time, lerp(max_response_time, min_response_time,
                                          clamp(variation / normal_variation_threshold, 0.0, 1.0)))
    
    # Ajustar baseado em eventos recentes
    if not events.is_empty():
        var max_event_intensity: float = 0.0
        for event in events:
            max_event_intensity = max(max_event_intensity, event.intensity)
        
        if max_event_intensity > 0.5:
            base_time = lerp(base_time, min_response_time, max_event_intensity)
    
    # Ajustar baseado na duração do contato
    if current_dynamics.has("contact_duration"):
        var duration: float = current_dynamics.contact_duration
        if duration > stabilization_time:
            # Contato estável permite tempos de resposta mais longos
            base_time = max(base_time, min_response_time * 2.0)
        elif duration < 0.1:
            # Contato muito recente, responder rapidamente
            base_time = min(base_time, min_response_time * 1.5)
    
    # Garantir limites
    return clamp(base_time, min_response_time, max_response_time)

func get_event_score(events: Array[TemporalEvent], current_time: float, 
                    time_window: float = 1.0) -> float:
    """
    Calcula pontuação de evento baseada em eventos recentes.
    
    Args:
        events: Array de eventos temporais
        current_time: Tempo atual
        time_window: Janela de tempo para considerar eventos (segundos)
    
    Returns:
        Pontuação de evento (0.0 a 1.0)
    """
    if events.is_empty():
        return 0.0
    
    var recent_events: Array[TemporalEvent] = []
    for event in events:
        if current_time - event.timestamp <= time_window:
            recent_events.append(event)
    
    if recent_events.is_empty():
        return 0.0
    
    # Calcular pontuação baseada em intensidade e tipo de evento
    var total_score: float = 0.0
    var weight_sum: float = 0.0
    
    for event in recent_events:
        var weight: float = 1.0
        var event_score: float = event.intensity
        
        # Ajustar peso baseado no tipo de evento
        match event.type:
            TemporalEventType.EVENT_IMPACT:
                weight = 2.0  # Impactos são mais importantes
            TemporalEventType.EVENT_BOUNCE:
                weight = 1.5
            TemporalEventType.EVENT_SLIDE:
                weight = 1.2
            TemporalEventType.EVENT_UNSTABLE:
                weight = 1.8
            TemporalEventType.EVENT_STABILIZATION:
                weight = 0.5  # Estabilização é menos crítica
            TemporalEventType.EVENT_CONTACT_START, TemporalEventType.EVENT_CONTACT_END:
                weight = 0.8
        
        # Ajustar baseado na recência (eventos mais recentes têm mais peso)
        var recency: float = 1.0 - clamp((current_time - event.timestamp) / time_window, 0.0, 1.0)
        weight *= (0.5 + recency * 0.5)
        
        total_score += event_score * weight
        weight_sum += weight
    
    if weight_sum > 0.0:
        var avg_score: float = total_score / weight_sum
        # Suavizar com pontuação anterior
        if has_meta("last_event_score"):
            var last_score: float = get_meta("last_event_score")
            avg_score = lerp(last_score, avg_score, 1.0 - event_intensity_smoothing)
        
        set_meta("last_event_score", avg_score)
        return clamp(avg_score, 0.0, 1.0)
    
    return 0.0

func get_event_history(time_window: float = 5.0) -> Array[Dictionary]:
    """
    Retorna histórico de eventos dentro da janela de tempo.
    
    Args:
        time_window: Janela de tempo em segundos
    
    Returns:
        Array de dicionários com eventos
    """
    var current_time: float = Time.get_ticks_msec() / 1000.0
    var recent_events: Array[Dictionary] = []
    
    for event in _event_history:
        if current_time - event.timestamp <= time_window:
            recent_events.append(event.to_dictionary())
    
    return recent_events

func get_time_series_data(samples: int = 50) -> Dictionary:
    """
    Retorna dados da série temporal para visualização.
    
    Args:
        samples: Número máximo de amostras a retornar
    
    Returns:
        Dicionário com dados da série temporal
    """
    var compression_data: Array[float] = []
    var normal_variation_data: Array[float] = []
    var contact_data: Array[bool] = []
    var time_data: Array[float] = []
    
    # Coletar dados do TimeSeriesAnalysis
    if _time_series:
        var history_size: int = _time_series.compression_history.size()
        var start_idx: int = max(0, history_size - samples)
        
        for i in range(start_idx, history_size):
            compression_data.append(_time_series.compression_history[i])
            
            if i < _time_series.normal_history.size():
                normal_variation_data.append(0.0)  # Placeholder, cálculo real requer mais dados
            else:
                normal_variation_data.append(0.0)
            
            if i < _time_series.contact_history.size():
                contact_data.append(_time_series.contact_history[i])
            else:
                contact_data.append(false)
            
            if i < _time_series.timestamps.size():
                time_data.append(_time_series.timestamps[i])
            else:
                time_data.append(0.0)
    
    return {
        "compression": compression_data,
        "normal_variation": normal_variation_data,
        "contact": contact_data,
        "timestamps": time_data,
        "sample_count": compression_data.size(),
        "current_velocity": _time_series.compression_velocity if _time_series else 0.0,
        "current_normal_variation": _time_series.normal_variation if _time_series else 0.0
    }

func clear_history() -> void:
    """Limpa o histórico de eventos e séries temporais."""
    _event_history.clear()
    if _time_series:
        _time_series.compression_history.clear()
        _time_series.normal_history.clear()
        _time_series.contact_history.clear()
        _time_series.timestamps.clear()

# Funções internas
func _detect_events(current_time: float, has_contact: bool, compression: float, 
                   normal: Vector3, metrics_data: Dictionary) -> Array[TemporalEvent]:
    """Detecta eventos temporais baseados nos dados atuais."""
    var events: Array[TemporalEvent] = []
    
    # Verificar mudança de estado de contato
    if has_contact != _current_contact_state:
        var event_type: int
        if has_contact:
            event_type = TemporalEventType.EVENT_CONTACT_START
        else:
            event_type = TemporalEventType.EVENT_CONTACT_END
        
        var event: TemporalEvent = TemporalEvent.new(event_type, current_time, 0.5)
        event.position = Vector3.ZERO  # Seria melhor ter posição média dos raycasts
        event.compression = compression
        event.confidence = 0.8
        
        events.append(event)
    
    # Detectar impacto súbito
    if _time_series.compression_history.size() >= require_min_samples:
        var impact_event = detect_sudden_impact(
            _time_series.compression_velocity,
            _time_series.normal_variation,
            current_time,
            Vector3.ZERO  # Posição seria melhor calculada
        )
        
        if impact_event:
            events.append(impact_event)
    
    # Detectar deslizamento (alta variação de normal)
    if _time_series.normal_variation > normal_variation_threshold:
        var slide_event: TemporalEvent = TemporalEvent.new(
            TemporalEventType.EVENT_SLIDE, 
            current_time, 
            clamp(_time_series.normal_variation / (normal_variation_threshold * 2), 0.0, 1.0)
        )
        slide_event.normal = normal
        slide_event.confidence = 0.7
        slide_event.metadata = {
            "normal_variation": _time_series.normal_variation,
            "threshold": normal_variation_threshold
        }
        
        events.append(slide_event)
    
    # Detectar ricochete (compressão positiva após impacto recente)
    if current_time - _last_impact_time < 0.2 and _time_series.compression_velocity > bounce_threshold:
        var bounce_event: TemporalEvent = TemporalEvent.new(
            TemporalEventType.EVENT_BOUNCE,
            current_time,
            clamp(_time_series.compression_velocity / (bounce_threshold * 2), 0.0, 1.0)
        )
        bounce_event.velocity = Vector3(0.0, _time_series.compression_velocity, 0.0)
        bounce_event.confidence = 0.6
        
        events.append(bounce_event)
    
    # Detectar estabilização (contato estável por tempo suficiente)
    if has_contact and _time_series.contact_duration > stabilization_time:
        var stability_analysis = calculate_contact_stability(
            _time_series.contact_history,
            _time_series.compression_history
        )
        
        if stability_analysis.stable and current_time - _last_stable_time > stabilization_time * 2:
            var stabilization_event: TemporalEvent = TemporalEvent.new(
                TemporalEventType.EVENT_STABILIZATION,
                current_time,
                stability_analysis.score
            )
            stabilization_event.stability_score = stability_analysis.score
            stabilization_event.confidence = 0.9
            stabilization_event.metadata = stability_analysis
            
            events.append(stabilization_event)
            _last_stable_time = current_time
    
    # Detectar instabilidade (alta variância em contato)
    if has_contact and _time_series.compression_variance > 0.05:
        var unstable_event: TemporalEvent = TemporalEvent.new(
            TemporalEventType.EVENT_UNSTABLE,
            current_time,
            clamp(_time_series.compression_variance * 10.0, 0.0, 1.0)
        )
        unstable_event.stability_score = 1.0 - clamp(_time_series.compression_variance * 10.0, 0.0, 1.0)
        unstable_event.confidence = 0.7
        
        events.append(unstable_event)
    
    # Adicionar todos os eventos ao histórico
    for event in events:
        _add_event_to_history(event)
    
    return events

func _update_contact_state(has_contact: bool, current_time: float) -> void:
    """Atualiza estado de contato e emite sinais se necessário."""
    if has_contact != _current_contact_state:
        _last_contact_change_time = current_time
        _current_contact_state = has_contact

func _calculate_response_time_suggestion(current_time: float, events: Array[TemporalEvent]) -> Dictionary:
    """Calcula sugestão de tempo de resposta."""
    var dynamics: Dictionary = {
        "compression_velocity": _time_series.compression_velocity,
        "normal_variation": _time_series.normal_variation,
        "contact_duration": _time_series.contact_duration
    }
    
    var suggested_time: float = suggest_response_time(dynamics, events)
    
    # Determinar razão
    var reason: String = "normal_operation"
    
    if not events.is_empty():
        var primary_event = events[0]
        match primary_event.type:
            TemporalEventType.EVENT_IMPACT:
                reason = "impact_detected"
            TemporalEventType.EVENT_SLIDE:
                reason = "sliding_detected"
            TemporalEventType.EVENT_BOUNCE:
                reason = "bounce_detected"
            TemporalEventType.EVENT_UNSTABLE:
                reason = "unstable_contact"
            _:
                reason = "event_detected"
    elif _time_series.compression_velocity > impact_threshold * 0.3:
        reason = "high_compression_velocity"
    elif _time_series.normal_variation > normal_variation_threshold * 0.5:
        reason = "high_normal_variation"
    
    # Emitir sinal
    response_time_suggested.emit(suggested_time, reason)
    
    return {"time": suggested_time, "reason": reason}

func _calculate_event_score(events: Array[TemporalEvent], current_time: float) -> float:
    """Calcula pontuação de evento."""
    return get_event_score(events, current_time)

func _emit_contact_duration_if_changed() -> void:
    """Emite sinal se a duração do contato mudou significativamente."""
    # Esta função seria chamada periodicamente para emitir atualizações
    # Por simplicidade, emitimos sempre que atualizamos
    contact_duration_updated.emit(_time_series.contact_duration)

func _add_event_to_history(event: TemporalEvent) -> void:
    """Adiciona evento ao histórico."""
    _event_history.append(event)
    
    # Limitar tamanho do histórico
    if _event_history.size() > 1000:
        _event_history.remove_at(0)

# Funções públicas para integração
func get_current_dynamics() -> Dictionary:
    """Retorna dinâmica temporal atual."""
    if not _time_series:
        return {}
    
    return {
        "compression_velocity": _time_series.compression_velocity,
        "normal_variation": _time_series.normal_variation,
        "contact_duration": _time_series.contact_duration,
        "avg_compression": _time_series.avg_compression,
        "compression_variance": _time_series.compression_variance,
        "has_contact": _current_contact_state,
        "time_since_contact_change": Time.get_ticks_msec() / 1000.0 - _last_contact_change_time,
        "time_since_last_impact": Time.get_ticks_msec() / 1000.0 - _last_impact_time,
        "time_since_last_stable": Time.get_ticks_msec() / 1000.0 - _last_stable_time
    }

func get_system_uptime() -> float:
    """Retorna tempo de atividade do sistema em segundos."""
    return Time.get_ticks_msec() / 1000.0 - _system_start_time

func reset_temporal_state() -> void:
    """Redefine o estado temporal (útil para reinícios)."""
    _current_contact_state = false
    _last_contact_change_time = Time.get_ticks_msec() / 1000.0
    _last_impact_time = 0.0
    _last_stable_time = 0.0
    clear_history()
    
    # Reinstanciar time series
    _time_series = TimeSeriesAnalysis.new(int(history_window * 60))

func set_impact_threshold(threshold: float) -> void:
    """Define limiar de detecção de impacto."""
    impact_threshold = max(threshold, 0.1)

func set_normal_variation_threshold(threshold: float) -> void:
    """Define limiar de variação de normal."""
    normal_variation_threshold = max(threshold, 1.0)

func is_in_contact() -> bool:
    """Retorna se está atualmente em contato."""
    return _current_contact_state

func get_last_impact_intensity() -> float:
    """Retorna intensidade do último impacto detectado."""
    if _event_history.is_empty():
        return 0.0
    
    for i in range(_event_history.size() - 1, -1, -1):
        if _event_history[i].type == TemporalEventType.EVENT_IMPACT:
            return _event_history[i].intensity
    
    return 0.0