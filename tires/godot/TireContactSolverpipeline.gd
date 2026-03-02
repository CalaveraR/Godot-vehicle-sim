# Sistema central de decisão física (ORQUESTRADOR PRINCIPAL)
class_name TireContactSolver extends Node

### REFERÊNCIAS (INJETADAS PELO SISTEMA PRINCIPAL) ###
var shader_reader: ShaderContactReader
var raycast_reader: RaycastSanityReader
var patch_builder: ContactPatchBuilder
var confidence_calc: ConfidenceCalculator
var contact_state: ContactState

### SUBMODELOS FÍSICOS (GERENCIADOS INTERNAMENTE) ###
var normal_model: NormalForceModel
var slip_model: SlipForceModel
var torque_model: TorqueModel

### ESTADO INTERNO ###
var current_patch: ContactPatch = null
var previous_samples: Array[TireSample] = []
var history: TemporalHistory = TemporalHistory.new()
var last_solve_time: float = 0.0

# Regime de força e transições emergentes
enum ForceRegime { STANDARD, DEGRADED, FALLBACK }
var current_regime: ForceRegime = ForceRegime.STANDARD
var last_regime: ForceRegime = ForceRegime.STANDARD
var regime_change_time: float = 0.0
var regime_persistence: float = 0.0  # Segundos que o regime atual persiste
var _regime_slip_history: Array = []  # Histórico de slip para persistência
var _regime_transition_count: int = 0  # Contador de transições (para debug)

# Métricas de esforço percebido (apenas para validação)
var effort_metric_history: Array = []
var max_effort_metric_history: int = 100
var _last_slip_vector: Vector2 = Vector2.ZERO

### CONFIGURAÇÃO EXPORTADA ###
@export_group("Temporal")
@export var solve_rate: int = 120  # Hz
@export_range(0.0, 1.0) var confidence_threshold: float = 0.55

@export_group("Model Configuration")
@export var enable_normal_model: bool = true
@export var enable_slip_model: bool = true
@export var enable_torque_model: bool = true
@export var enable_history_tracking: bool = true

@export_group("ContactState Integration")
@export var use_contact_state_processing: bool = true
@export var contact_state_debug: bool = false

@export_group("Regime Transitions")
@export var enable_regime_transitions: bool = true
@export var fallback_to_degraded_threshold: float = 50.0  # Energia mínima para sair do fallback
@export var degraded_to_standard_threshold: float = 30.0  # Energia máxima para voltar ao standard
@export var regime_hysteresis: float = 5.0  # Histerese para evitar oscilações
@export var min_regime_persistence: float = 0.1  # Segundos mínimos em um regime
@export var slip_persistence_factor: float = 0.5  # Quanto slip constante retarda transição

@export_group("Fallback Behavior")
@export var fallback_enable_minimal_torque: bool = true  # Torque residual mínimo
@export var fallback_torque_multiplier: float = 0.01  # Multiplicador para torque residual

@export_group("Effort Metrics")
@export var enable_effort_metrics: bool = false  # Desligado por padrão (só para validação)
@export var effort_metric_smoothing: float = 0.1
@export var log_effort_metrics: bool = false

@export_group("Debug")
@export var debug_mode: bool = false
@export var log_sample_counts: bool = false
@export var log_force_changes: bool = false
@export var log_regime_changes: bool = true
@export var log_regime_details: bool = false  # Log detalhado de decisões de regime

### INICIALIZAÇÃO ###
func initialize(
    shader_reader_ref: ShaderContactReader,
    raycast_reader_ref: RaycastSanityReader,
    patch_builder_ref: ContactPatchBuilder,
    confidence_calc_ref: ConfidenceCalculator,
    contact_state_ref: ContactState
) -> void:
    shader_reader = shader_reader_ref
    raycast_reader = raycast_reader_ref
    patch_builder = patch_builder_ref
    confidence_calc = confidence_calc_ref
    contact_state = contact_state_ref
    
    # Inicializa submodelos
    _initialize_models()
    
    if debug_mode:
        print("[TireContactSolver] Inicializado com rate: %d Hz" % solve_rate)
        print("[TireContactSolver] Regime transitions: %s" % enable_regime_transitions)
        print("[TireContactSolver] Fallback torque: %s (mult: %.3f)" % 
              [fallback_enable_minimal_torque, fallback_torque_multiplier])

func _initialize_models() -> void:
    """Cria e configura os submodelos físicos."""
    
    # NormalForceModel - Forças normais (Fz)
    normal_model = NormalForceModel.new()
    normal_model.configure({
        "contact_stiffness": 100000.0,
        "contact_damping": 500.0,
        "max_damping_force": 5000.0,
        "enable_contact_damping": true,
        "debug_mode": debug_mode
    })
    
    # SlipForceModel - Forças longitudinais/laterais (Fx, Fy)
    slip_model = SlipForceModel.new()
    slip_model.configure({
        "longitudinal_stiffness": 8.0,
        "lateral_stiffness": 10.0,
        "peak_friction_coefficient": 1.2,
        "sliding_friction_coefficient": 0.8,
        "use_slip_angle_for_stiffness": true,
        "slip_angle_sensitivity": 0.5,
        "enable_per_sample_calculation": true,
        "debug_mode": debug_mode
    })
    
    # TorqueModel - Torque de auto-alinhamento (Mz)
    torque_model = TorqueModel.new()
    torque_model.configure({
        "pneumatic_trail_length": 0.05,
        "mechanical_trail_length": 0.02,
        "aligning_stiffness": 100.0,
        "max_aligning_torque": 100.0,
        "trail_reduction_at_saturation": 0.3,
        "debug_mode": debug_mode
    })

### LOOP PRINCIPAL ###
func solve(delta: float, global_transform: Transform3D, exclude_nodes: Array[Node]) -> Dictionary:
    """Processa um frame completo de física do pneu."""
    
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # Atualiza persistência do regime
    regime_persistence = current_time - regime_change_time
    
    # CONTROLE DE TAXA
    if current_time - last_solve_time < 1.0 / float(solve_rate):
        if use_contact_state_processing:
            return contact_state.get_processed_forces(
                _get_zero_forces(),
                contact_state.get_last_valid_patch(),
                delta
            )
        else:
            return _get_zero_forces()
    
    last_solve_time = current_time
    
    # 1. COLETA DE DADOS
    var shader_samples = shader_reader.read_shader_data(
        global_transform,
        delta,
        previous_samples
    )
    
    var raycast_samples = raycast_reader.read_raycasts(
        global_transform,
        exclude_nodes
    )
    
    if log_sample_counts:
        print("[TireContactSolver] Amostras: Shader=%d, Raycast=%d" % [shader_samples.size(), raycast_samples.size()])
    
    # 2. HISTÓRICO TEMPORAL
    if enable_history_tracking and current_patch:
        history.add_frame(
            current_patch.max_penetration,
            current_patch.average_slip,
            current_patch.patch_confidence,
            current_time
        )
    
    # 3. CONSTRUÇÃO DO PATCH
    current_patch = patch_builder.build_contact_patch(
        shader_samples,
        raycast_samples,
        history
    )
    
    # Atualiza histórico de slip para persistência de regime
    if current_patch:
        _update_regime_slip_history(current_patch.average_slip)
    
    # 4. DETERMINAÇÃO DO REGIME (EMERGENTE)
    _update_force_regime(current_patch, delta)
    
    # 5. CÁLCULO DE FORÇAS (COM REGIME APLICADO)
    var raw_forces = _calculate_forces_with_regime(current_patch, delta, current_regime)
    
    # 6. MÉTRICA DE ESFORÇO (APENAS PARA VALIDAÇÃO)
    if enable_effort_metrics:
        var effort_metric = _calculate_effort_metric(raw_forces, current_patch, delta)
        raw_forces["effort_metric"] = effort_metric
        
        if log_effort_metrics:
            print("[TireContactSolver] Effort metric: %.2f (regime: %s)" % 
                  [effort_metric, _regime_to_string(current_regime)])
    
    # 7. PROCESSAMENTO COM CONTACT STATE
    var processed_forces = raw_forces
    if use_contact_state_processing:
        processed_forces = contact_state.get_processed_forces(
            raw_forces,
            current_patch,
            delta
        )
        
        if contact_state_debug:
            print("[TireContactSolver] ContactState processado")
    
    # 8. PREPARA PRÓXIMO FRAME
    previous_samples = shader_samples
    
    if log_force_changes and debug_mode:
        print("[TireContactSolver] Forças: Fx=%.1f, Fy=%.1f, Fz=%.1f, Mz=%.1f (regime: %s)" % [
            processed_forces.get("Fx", 0.0),
            processed_forces.get("Fy", 0.0),
            processed_forces.get("Fz", 0.0),
            processed_forces.get("Mz", 0.0),
            _regime_to_string(current_regime)
        ])
    
    return processed_forces

func _calculate_forces_with_regime(patch: ContactPatch, delta: float, regime: ForceRegime) -> Dictionary:
    """Calcula forças aplicando o regime atual."""
    
    if not patch or patch.samples.is_empty() or patch.total_weight <= 0:
        return _get_zero_forces()
    
    # Forças base (modelos físicos completos)
    var forces = _calculate_raw_forces(patch, delta)
    
    # Aplica modificadores baseados no regime
    match regime:
        ForceRegime.STANDARD:
            # Nenhuma modificação - modelo completo
            pass
            
        ForceRegime.DEGRADED:
            # Reduz confiança e limita forças
            var degradation_factor = 0.7
            forces.Fx *= degradation_factor
            forces.Fy *= degradation_factor
            forces.Fz *= degradation_factor
            forces.Mz *= degradation_factor
            forces["regime_modifier"] = degradation_factor
            
        ForceRegime.FALLBACK:
            # Modelo simplificado - apenas forças básicas
            forces = _calculate_fallback_forces(patch, delta)
            forces["regime_modifier"] = 0.5
    
    forces["force_regime"] = _regime_to_string(regime)
    forces["regime_persistence"] = regime_persistence
    
    return forces

func _calculate_raw_forces(patch: ContactPatch, delta: float) -> Dictionary:
    """Calcula forças brutas usando os submodelos físicos completos."""
    
    # A. NORMAL FORCE MODEL (Fz)
    var normal_data = {
        "total_force": 0.0,
        "load_per_sample": [],
        "metadata": {}
    }
    
    if enable_normal_model:
        normal_data = normal_model.compute_normal_force(patch, delta)
    else:
        normal_data.total_force = patch.total_weight * 9.81 * 100.0
        normal_data.load_per_sample = [normal_data.total_force / patch.samples.size()] * patch.samples.size()
    
    # B. SLIP FORCE MODEL (Fx, Fy)
    var slip_forces = {
        "Fx": 0.0,
        "Fy": 0.0,
        "metadata": {}
    }
    
    if enable_slip_model:
        slip_forces = slip_model.compute_slip_forces(
            patch.samples,
            normal_data.total_force,
            normal_data.load_per_sample,
            delta
        )
    else:
        var slip_magnitude = min(patch.average_slip.length(), 1.0)
        var long_friction = 0.8 * (1.0 - slip_magnitude * 0.5)
        var lat_friction = 1.2 * (1.0 - slip_magnitude * 0.3)
        
        slip_forces.Fx = patch.average_slip.x * normal_data.total_force * long_friction
        slip_forces.Fy = patch.average_slip.y * normal_data.total_force * lat_friction
    
    # C. TORQUE MODEL (Mz)
    var torque_data = {
        "aligning_torque": 0.0,
        "metadata": {}
    }
    
    if enable_torque_model:
        torque_data = torque_model.compute_self_aligning_torque(
            patch.samples,
            slip_forces,
            normal_data.load_per_sample,
            patch.average_slip,
            normal_data.total_force,
            delta
        )
    
    # D. CONFIDENCE FINAL
    var confidence_factor = _calculate_confidence_factor(patch.patch_confidence)
    
    # E. AGREGAÇÃO
    return {
        "Fx": slip_forces.Fx * confidence_factor,
        "Fy": slip_forces.Fy * confidence_factor,
        "Fz": normal_data.total_force * confidence_factor,
        "Mz": torque_data.aligning_torque * confidence_factor,
        "patch_confidence": patch.patch_confidence,
        "confidence_factor": confidence_factor,
        "sample_count": patch.samples.size(),
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "normal_model_info": normal_data.metadata,
        "slip_model_info": slip_forces.metadata,
        "torque_model_info": torque_data.metadata,
        "patch_info": {
            "max_penetration": patch.max_penetration,
            "average_slip": patch.average_slip,
            "total_weight": patch.total_weight,
            "patch_velocity": patch.get("patch_velocity", Vector3.ZERO),
            "average_pen_vel": patch.get("average_pen_vel", 0.0)
        },
        "raw_forces": true
    }

func _calculate_fallback_forces(patch: ContactPatch, delta: float) -> Dictionary:
    """Forças de fallback (modelo simplificado) com torque residual opcional."""
    
    if not patch or patch.samples.is_empty() or patch.total_weight <= 0:
        return _get_zero_forces()
    
    # Modelo extremamente simplificado
    var vertical_force = patch.total_weight * 9.81 * 100.0
    
    # Coeficientes fixos (não dependem do slip)
    var long_friction = 0.6
    var lat_friction = 0.8
    
    var longitudinal_force = clamp(patch.average_slip.x, -1.0, 1.0) * vertical_force * long_friction
    var lateral_force = clamp(patch.average_slip.y, -1.0, 1.0) * vertical_force * lat_friction
    
    # Torque residual mínimo (opcional) para melhor sensação no volante
    var residual_torque = 0.0
    if fallback_enable_minimal_torque and abs(patch.average_slip.y) > 0.01:
        residual_torque = sign(patch.average_slip.y) * vertical_force * fallback_torque_multiplier
    
    return {
        "Fx": longitudinal_force,
        "Fy": lateral_force,
        "Fz": vertical_force * 0.8,  # Reduzido no fallback
        "Mz": residual_torque,
        "patch_confidence": patch.patch_confidence * 0.5,
        "sample_count": patch.samples.size(),
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "fallback_forces": true,
        "residual_torque": fallback_enable_minimal_torque
    }

### SISTEMA DE REGIME EMERGENTE REFINADO ###
func _update_regime_slip_history(slip_vector: Vector2) -> void:
    """Atualiza o histórico de slip para determinar persistência de regime."""
    _last_slip_vector = slip_vector
    _regime_slip_history.append({
        "time": Time.get_ticks_msec() / 1000.0,
        "slip": slip_vector,
        "magnitude": slip_vector.length()
    })
    
    # Mantém apenas os últimos 10 frames (aproximadamente 0.16s a 60Hz)
    if _regime_slip_history.size() > 10:
        _regime_slip_history.remove_at(0)

func _calculate_slip_persistence() -> float:
    """Calcula quanto slip constante existe no histórico."""
    if _regime_slip_history.size() < 3:
        return 0.0
    
    var total_variation = 0.0
    var max_magnitude = 0.0
    
    for i in range(1, _regime_slip_history.size()):
        var current = _regime_slip_history[i].slip
        var previous = _regime_slip_history[i-1].slip
        total_variation += (current - previous).length()
        max_magnitude = max(max_magnitude, _regime_slip_history[i].magnitude)
    
    # Baixa variação + alta magnitude = slip constante significativo
    if max_magnitude < 0.1:
        return 0.0
    
    var avg_variation = total_variation / (_regime_slip_history.size() - 1)
    var slip_constant = 1.0 - clamp(avg_variation / max_magnitude, 0.0, 1.0)
    
    return slip_constant * max_magnitude

func _update_force_regime(patch: ContactPatch, delta: float) -> void:
    """Atualiza o regime de força baseado em condições emergentes."""
    
    if not enable_regime_transitions or not patch:
        current_regime = ForceRegime.STANDARD
        return
    
    # Garante persistência mínima no regime atual
    if regime_persistence < min_regime_persistence:
        return
    
    var new_regime = current_regime
    var thermal_state = patch.get_thermal_state()  # Método explícito do ContactPatch
    
    # Extrai dados do estado térmico
    var patch_energy = thermal_state.get("stored_energy", 0.0)
    var patch_temperature = thermal_state.get("temperature", 0.0)
    
    # Calcula persistência de slip
    var slip_persistence = _calculate_slip_persistence()
    var slip_factor = slip_persistence * slip_persistence_factor
    
    # Fatores de decisão
    var energy_factor = patch_energy
    var confidence_factor = patch.patch_confidence
    var temperature_factor = patch_temperature * 0.1  # Temperatura tem menor peso
    
    # TRANSIÇÕES EMERGENTES (sem timer fixo)
    match current_regime:
        ForceRegime.FALLBACK:
            # FALLBACK → DEGRADED: precisa de energia suficiente
            var required_energy = fallback_to_degraded_threshold + slip_factor * 10.0
            if energy_factor > required_energy:
                new_regime = ForceRegime.DEGRADED
                _log_regime_change("FALLBACK", "DEGRADED", 
                    "energy=%.1f > %.1f (slip_factor=%.2f)" % 
                    [energy_factor, required_energy, slip_factor])
        
        ForceRegime.DEGRADED:
            # DEGRADED → STANDARD: energia baixa, confiança boa e slip não constante
            var max_energy_for_standard = degraded_to_standard_threshold - slip_factor * 5.0
            
            if (energy_factor < max_energy_for_standard and 
                confidence_factor > 0.7 and 
                slip_factor < 0.3):
                
                new_regime = ForceRegime.STANDARD
                _log_regime_change("DEGRADED", "STANDARD",
                    "energy=%.1f < %.1f, conf=%.2f, slip_factor=%.2f" %
                    [energy_factor, max_energy_for_standard, confidence_factor, slip_factor])
            
            # DEGRADED → FALLBACK: energia muito baixa ou confiança ruim
            elif (energy_factor < fallback_to_degraded_threshold - regime_hysteresis or 
                  confidence_factor < 0.3):
                
                new_regime = ForceRegime.FALLBACK
                _log_regime_change("DEGRADED", "FALLBACK",
                    "energy=%.1f < %.1f or conf=%.2f" %
                    [energy_factor, fallback_to_degraded_threshold - regime_hysteresis, confidence_factor])
        
        ForceRegime.STANDARD:
            # STANDARD → DEGRADED: alta energia, baixa confiança ou slip constante
            var min_energy_for_degraded = degraded_to_standard_threshold + regime_hysteresis + slip_factor * 5.0
            
            if (energy_factor > min_energy_for_degraded or 
                confidence_factor < 0.5 or 
                slip_factor > 0.5):
                
                new_regime = ForceRegime.DEGRADED
                _log_regime_change("STANDARD", "DEGRADED",
                    "energy=%.1f > %.1f or conf=%.2f or slip_factor=%.2f" %
                    [energy_factor, min_energy_for_degraded, confidence_factor, slip_factor])
    
    # Atualiza regime se mudou
    if new_regime != current_regime:
        last_regime = current_regime
        current_regime = new_regime
        regime_change_time = Time.get_ticks_msec() / 1000.0
        regime_persistence = 0.0
        _regime_transition_count += 1

func _log_regime_change(from_regime: String, to_regime: String, details: String) -> void:
    """Log de mudanças de regime com detalhes."""
    if log_regime_changes and debug_mode:
        print("[TireContactSolver] Transição: %s → %s (%s)" % [from_regime, to_regime, details])
    
    if log_regime_details and debug_mode:
        var log_entry = {
            "timestamp": Time.get_ticks_msec() / 1000.0,
            "from": from_regime,
            "to": to_regime,
            "details": details,
            "transition_count": _regime_transition_count
        }
        # Aqui você poderia armazenar em um array para histórico se necessário

### MÉTRICA DE ESFORÇO PERCEBIDO ###
func _calculate_effort_metric(forces: Dictionary, patch: ContactPatch, delta: float) -> float:
    """
    Métrica de "esforço percebido" para validação.
    NÃO interfere na física, apenas mede para análise.
    """
    
    if not patch:
        return 0.0
    
    # 1. Componente de força lateral × taxa de guinada (estimada)
    var yaw_rate = patch.get("estimated_yaw_rate", 0.0)
    var lateral_effort = abs(forces.get("Fy", 0.0)) * abs(yaw_rate)
    
    # 2. Componente de força longitudinal × razão de deslizamento
    var slip_ratio = abs(patch.average_slip.x)
    var longitudinal_effort = abs(forces.get("Fx", 0.0)) * slip_ratio
    
    # 3. Estado térmico do patch (usando método explícito)
    var thermal_state = patch.get_thermal_state()
    var patch_energy = thermal_state.get("stored_energy", 0.0)
    var patch_temperature = thermal_state.get("temperature", 0.0)
    
    # 4. Confiança inversa (baixa confiança = mais esforço)
    var confidence_penalty = 1.0 - patch.patch_confidence
    
    # 5. Regime atual (fallback = mais esforço percebido)
    var regime_penalty = 0.0
    match current_regime:
        ForceRegime.FALLBACK:
            regime_penalty = 50.0
        ForceRegime.DEGRADED:
            regime_penalty = 20.0
        _:
            regime_penalty = 0.0
    
    # 6. Combinação ponderada
    var effort = (
        lateral_effort * 0.3 +
        longitudinal_effort * 0.25 +
        patch_energy * 0.2 +
        patch_temperature * 0.05 +
        confidence_penalty * 30.0 * 0.1 +
        regime_penalty * 0.1
    )
    
    # Suavização
    var last_effort = effort_metric_history.back().effort if not effort_metric_history.is_empty() else effort
    var smoothed_effort = lerp(last_effort, effort, effort_metric_smoothing)
    
    # Armazena no histórico
    effort_metric_history.append({
        "time": Time.get_ticks_msec() / 1000.0,
        "effort": smoothed_effort,
        "lateral_effort": lateral_effort,
        "longitudinal_effort": longitudinal_effort,
        "patch_energy": patch_energy,
        "patch_temperature": patch_temperature,
        "regime": _regime_to_string(current_regime),
        "confidence": patch.patch_confidence
    })
    
    # Limita histórico
    if effort_metric_history.size() > max_effort_metric_history:
        effort_metric_history.remove_at(0)
    
    return smoothed_effort

### FUNÇÕES AUXILIARES ###
func _calculate_confidence_factor(patch_confidence: float) -> float:
    """Suaviza a transição baseada na confiança."""
    var edge0 = confidence_threshold - 0.2
    var edge1 = confidence_threshold + 0.2
    
    var t = clamp((patch_confidence - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

func _get_zero_forces() -> Dictionary:
    """Retorna um dicionário de forças zerado."""
    return {
        "Fx": 0.0,
        "Fy": 0.0,
        "Fz": 0.0,
        "Mz": 0.0,
        "patch_confidence": 0.0,
        "confidence_factor": 0.0,
        "sample_count": 0,
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "normal_model_info": {},
        "slip_model_info": {},
        "torque_model_info": {},
        "patch_info": {},
        "raw_forces": false,
        "force_regime": _regime_to_string(current_regime)
    }

func _regime_to_string(regime: ForceRegime) -> String:
    """Converte enum do regime para string."""
    match regime:
        ForceRegime.STANDARD:
            return "STANDARD"
        ForceRegime.DEGRADED:
            return "DEGRADED"
        ForceRegime.FALLBACK:
            return "FALLBACK"
        _:
            return "UNKNOWN"

### MÉTODOS DE CONTROLE ###
func set_regime_transitions(enabled: bool) -> void:
    """Ativa/desativa transições de regime."""
    enable_regime_transitions = enabled
    if debug_mode:
        print("[TireContactSolver] Regime transitions: %s" % enabled)

func set_force_regime(regime: String) -> void:
    """Força um regime específico (para debug)."""
    match regime.to_upper():
        "STANDARD":
            current_regime = ForceRegime.STANDARD
        "DEGRADED":
            current_regime = ForceRegime.DEGRADED
        "FALLBACK":
            current_regime = ForceRegime.FALLBACK
    
    regime_change_time = Time.get_ticks_msec() / 1000.0
    regime_persistence = 0.0
    
    if debug_mode:
        print("[TireContactSolver] Regime forçado para: %s" % regime)

func set_effort_metrics(enabled: bool) -> void:
    """Ativa/desativa métricas de esforço."""
    enable_effort_metrics = enabled
    if debug_mode:
        print("[TireContactSolver] Effort metrics: %s" % enabled)

### FUNÇÕES PÚBLICAS PARA DEBUG/MONITORAMENTO ###
func get_current_patch() -> ContactPatch:
    return current_patch

func get_patch_confidence() -> float:
    return current_patch.patch_confidence if current_patch else 0.0

func get_sample_count() -> int:
    return current_patch.samples.size() if current_patch else 0

func get_current_regime() -> String:
    """Retorna o regime atual como string."""
    return _regime_to_string(current_regime)

func get_regime_statistics() -> Dictionary:
    """Retorna estatísticas do sistema de regime."""
    return {
        "current_regime": _regime_to_string(current_regime),
        "last_regime": _regime_to_string(last_regime),
        "persistence": regime_persistence,
        "transition_count": _regime_transition_count,
        "slip_persistence": _calculate_slip_persistence(),
        "regime_history_size": _regime_slip_history.size()
    }

func get_effort_metrics() -> Dictionary:
    """Retorna métricas de esforço para análise."""
    if effort_metric_history.is_empty():
        return {"current": 0.0, "average": 0.0, "max": 0.0}
    
    var current = effort_metric_history.back().effort
    var sum_effort = 0.0
    var max_effort = 0.0
    var min_effort = INF
    
    for entry in effort_metric_history:
        sum_effort += entry.effort
        max_effort = max(max_effort, entry.effort)
        min_effort = min(min_effort, entry.effort)
    
    return {
        "current": current,
        "average": sum_effort / effort_metric_history.size(),
        "max": max_effort,
        "min": min_effort,
        "history_size": effort_metric_history.size(),
        "regime": _regime_to_string(current_regime),
        "trend": _calculate_effort_trend()
    }

func _calculate_effort_trend() -> float:
    """Calcula tendência do esforço (positivo = aumentando, negativo = diminuindo)."""
    if effort_metric_history.size() < 10:
        return 0.0
    
    var recent = effort_metric_history.slice(-10)
    var first = recent[0].effort
    var last = recent[-1].effort
    
    return (last - first) / 10.0  # Taxa de mudança por amostra

func get_debug_info() -> Dictionary:
    """Retorna informações detalhadas para debug."""
    var info = {
        "solver_active": true,
        "solve_rate": solve_rate,
        "last_solve_time": last_solve_time,
        "current_regime": _regime_to_string(current_regime),
        "regime_persistence": regime_persistence,
        "enable_regime_transitions": enable_regime_transitions,
        "enable_effort_metrics": enable_effort_metrics,
        "regime_transitions": _regime_transition_count
    }
    
    if current_patch:
        var thermal_state = current_patch.get_thermal_state()
        info["patch"] = {
            "samples": current_patch.samples.size(),
            "confidence": current_patch.patch_confidence,
            "max_penetration": current_patch.max_penetration,
            "average_slip": current_patch.average_slip,
            "total_weight": current_patch.total_weight,
            "thermal_state": thermal_state,
            "slip_persistence": _calculate_slip_persistence()
        }
    
    info["history"] = {
        "frame_count": history.get_frame_count(),
        "avg_penetration": history.get_average_penetration(),
        "avg_slip": history.get_average_slip()
    }
    
    info["models"] = {
        "normal_model": enable_normal_model,
        "slip_model": enable_slip_model,
        "torque_model": enable_torque_model
    }
    
    # Métricas de esforço
    if enable_effort_metrics:
        info["effort_metrics"] = get_effort_metrics()
    
    return info

func reset() -> void:
    """Reinicia completamente o estado do solver."""
    current_patch = null
    previous_samples.clear()
    history.clear()
    last_solve_time = 0.0
    current_regime = ForceRegime.STANDARD
    last_regime = ForceRegime.STANDARD
    regime_change_time = Time.get_ticks_msec() / 1000.0
    regime_persistence = 0.0
    _regime_slip_history.clear()
    _regime_transition_count = 0
    effort_metric_history.clear()
    
    if contact_state and contact_state.has_method("reset"):
        contact_state.reset()
    
    if debug_mode:
        print("[TireContactSolver] Estado completamente reiniciado")

### CONFIGURAÇÃO EM TEMPO REAL ###
func configure_models(config: Dictionary) -> void:
    if normal_model and config.has("normal_model"):
        normal_model.configure(config.normal_model)
    
    if slip_model and config.has("slip_model"):
        slip_model.configure(config.slip_model)
    
    if torque_model and config.has("torque_model"):
        torque_model.configure(config.torque_model)
    
    # Configurações locais
    if config.has("solve_rate"):
        solve_rate = config.solve_rate
    
    if config.has("confidence_threshold"):
        confidence_threshold = config.confidence_threshold
    
    if config.has("use_contact_state_processing"):
        use_contact_state_processing = config.use_contact_state_processing
    
    # NOVAS CONFIGURAÇÕES
    if config.has("enable_regime_transitions"):
        enable_regime_transitions = config.enable_regime_transitions
    
    if config.has("fallback_to_degraded_threshold"):
        fallback_to_degraded_threshold = config.fallback_to_degraded_threshold
    
    if config.has("degraded_to_standard_threshold"):
        degraded_to_standard_threshold = config.degraded_to_standard_threshold
    
    if config.has("slip_persistence_factor"):
        slip_persistence_factor = config.slip_persistence_factor
    
    if config.has("fallback_enable_minimal_torque"):
        fallback_enable_minimal_torque = config.fallback_enable_minimal_torque
    
    if config.has("fallback_torque_multiplier"):
        fallback_torque_multiplier = config.fallback_torque_multiplier
    
    if config.has("enable_effort_metrics"):
        enable_effort_metrics = config.enable_effort_metrics

### INTERFACE DE MUDANÇA DINÂMICA ###
func set_model_enabled(model_name: String, enabled: bool) -> void:
    match model_name:
        "normal":
            enable_normal_model = enabled
        "slip":
            enable_slip_model = enabled
        "torque":
            enable_torque_model = enabled
        "history":
            enable_history_tracking = enabled
        "contact_state":
            use_contact_state_processing = enabled
        "regime_transitions":
            enable_regime_transitions = enabled
        "effort_metrics":
            enable_effort_metrics = enabled
    
    if debug_mode:
        print("[TireContactSolver] '%s' definido para: %s" % [model_name, enabled])

func set_debug_options(options: Dictionary) -> void:
    debug_mode = options.get("debug_mode", debug_mode)
    log_sample_counts = options.get("log_sample_counts", log_sample_counts)
    log_force_changes = options.get("log_force_changes", log_force_changes)
    contact_state_debug = options.get("contact_state_debug", contact_state_debug)
    log_regime_changes = options.get("log_regime_changes", log_regime_changes)
    log_regime_details = options.get("log_regime_details", log_regime_details)
    log_effort_metrics = options.get("log_effort_metrics", log_effort_metrics)

### EXPORTAÇÃO DE DADOS ###
func export_for_visualization() -> Dictionary:
    var data = {
        "patch": {},
        "models": {},
        "regime": _regime_to_string(current_regime),
        "regime_stats": get_regime_statistics(),
        "effort_metrics": {}
    }
    
    if current_patch:
        data.patch = {
            "sample_positions": [],
            "sample_confidences": [],
            "sample_forces": [],
            "thermal_state": current_patch.get_thermal_state(),
            "slip_vector": current_patch.average_slip
        }
        
        for sample in current_patch.samples:
            data.patch.sample_positions.append(sample.position)
            data.patch.sample_confidences.append(sample.confidence)
            data.patch.sample_forces.append({
                "penetration": sample.penetration,
                "slip_vector": sample.get("slip_vector", Vector2.ZERO)
            })
    
    if normal_model:
        data.models.normal = normal_model.get_debug_info()
    
    if slip_model:
        data.models.slip = slip_model.get_debug_info()
    
    if torque_model:
        data.models.torque = torque_model.get_debug_info()
    
    if enable_effort_metrics:
        data.effort_metrics = get_effort_metrics()
    
    return data