# res://core/integration/RaycastAnchorOrchestrator.gd
class_name RaycastAnchorOrchestrator
extends Node3D

# Controlador Principal de Integração
# Responsabilidades:
# - Orquestrar os componentes do sistema (raycasts, contratos, métricas, temporal, debug)
# - Expor API pública de alto nível
# - Gerenciar telemetria e diagnósticos
# - Validar a filosofia de design
#
# Conecta com: Todos os componentes via @onready (devem ser filhos diretos)

# Sinais do sistema
signal system_initialized()
signal system_shutdown()
signal contact_processed(result: Dictionary)
signal contract_applied(contract_summary: Dictionary)
signal diagnostic_updated(diagnostics: Dictionary)

# Componentes obrigatórios (devem existir como filhos)
@onready var raycast_base: RaycastAnchorBase = $RaycastAnchorBase
@onready var influence_system: InfluenceContractSystem = $InfluenceContractSystem
@onready var rate_limiter: ContractRateLimiter = $ContractRateLimiter
@onready var contract_merger: ContractMerger = $ContractMerger
@onready var metrics_processor: PhysicalMetricsProcessor = $PhysicalMetricsProcessor
@onready var temporal_system: TemporalDynamicsSystem = $TemporalDynamicsSystem
@onready var debug_visualizer: ContractDebugVisualizer = $ContractDebugVisualizer

# Configurações gerais
@export_group("General Settings")
@export var enabled: bool = true
@export var auto_initialize: bool = true
@export var update_rate: float = 60.0  # Hz, 0 para cada frame

# Configurações de filosofia
@export_group("Philosophy Settings")
@export var raycasts_as_optimization: bool = true
@export var raycasts_never_primary: bool = true
@export var max_shader_priority: int = 100
@export var require_safety_contracts: bool = true

# Configurações de componentes
@export_group("Component Settings")
@export var enable_metrics_processing: bool = true
@export var enable_temporal_analysis: bool = true
@export var enable_contract_system: bool = true
@export var enable_debug_visualization: bool = true

# Configurações de performance
@export_group("Performance Settings")
@export var max_contracts_per_update: int = 10
@export var metrics_history_size: int = 1000
@export var event_history_size: int = 500
@export var cache_neutral_contracts: bool = true

# Estado interno
var _is_initialized: bool = false
var _is_processing: bool = false
var _last_update_time: float = 0.0
var _update_timer: float = 0.0
var _system_diagnostics: Dictionary = {}
var _contact_history: Array[Dictionary] = []
var _contract_history: Array[Dictionary] = []
var _neutral_contract_cache: Dictionary = {}
var _current_contact_result: Dictionary = {}

const SYSTEM_VERSION: String = "1.0.0"

func _ready() -> void:
    if auto_initialize:
        initialize_system()
    _validate_philosophy()

func _process(delta: float) -> void:
    if not _is_initialized or not enabled or not _is_processing:
        return

    if update_rate > 0.0:
        _update_timer += delta
        var update_interval: float = 1.0 / update_rate
        if _update_timer >= update_interval:
            _update_timer = 0.0
            _process_system_update()
    else:
        _process_system_update()

func initialize_system() -> bool:
    if _is_initialized:
        return true

    print("Initializing Raycast Anchor Orchestrator v", SYSTEM_VERSION)

    if not _validate_philosophy():
        push_error("System philosophy validation failed!")
        return false

    var success: bool = true

    # Conectar sinais dos componentes
    if raycast_base:
        raycast_base.raycast_data_updated.connect(_on_raycast_data_updated)
        raycast_base.contact_started.connect(_on_contact_started)
        raycast_base.contact_ended.connect(_on_contact_ended)
    else:
        push_error("RaycastAnchorBase not found!")
        success = false

    if influence_system and enable_contract_system:
        influence_system.contract_created.connect(_on_contract_created)
        influence_system.contract_applied.connect(_on_contract_applied)
    elif enable_contract_system:
        push_error("InfluenceContractSystem not found!")
        success = false

    if rate_limiter:
        rate_limiter.rate_limit_check.connect(_on_rate_limit_check)
        rate_limiter.contract_rate_limited.connect(_on_contract_rate_limited)
    else:
        push_error("ContractRateLimiter not found!")
        success = false

    if contract_merger:
        contract_merger.contracts_merged.connect(_on_contracts_merged)
    else:
        push_error("ContractMerger not found!")
        success = false

    if metrics_processor and enable_metrics_processing:
        metrics_processor.metrics_calculated.connect(_on_metrics_calculated)
        metrics_processor.plausibility_changed.connect(_on_plausibility_changed)
    elif enable_metrics_processing:
        push_error("PhysicalMetricsProcessor not found!")
        success = false

    if temporal_system and enable_temporal_analysis:
        temporal_system.temporal_event_detected.connect(_on_temporal_event_detected)
        temporal_system.sudden_impact_detected.connect(_on_sudden_impact_detected)
    elif enable_temporal_analysis:
        push_error("TemporalDynamicsSystem not found!")
        success = false

    if debug_visualizer and enable_debug_visualization:
        debug_visualizer.debug_visualization_updated.connect(_on_debug_visualization_updated)
    elif enable_debug_visualization:
        push_warning("DebugVisualizer not found, visualization disabled")

    if success:
        _is_initialized = true
        _is_processing = true
        _last_update_time = Time.get_ticks_msec() / 1000.0
        _initialize_diagnostics()
        system_initialized.emit()
        print("System initialized successfully")
        return true
    else:
        push_error("System initialization failed")
        return false

func shutdown_system() -> void:
    if not _is_initialized:
        return
    print("Shutting down Raycast Anchor Orchestrator")
    _is_processing = false
    _is_initialized = false
    _contact_history.clear()
    _contract_history.clear()
    _neutral_contract_cache.clear()
    _current_contact_result.clear()
    system_shutdown.emit()

func _process_system_update() -> void:
    var current_time: float = Time.get_ticks_msec() / 1000.0
    var delta_time: float = current_time - _last_update_time

    var raycast_data: Dictionary = update_raycast_anchor()

    if enable_metrics_processing and metrics_processor:
        var metrics_result = process_physical_metrics(raycast_data)

        if enable_temporal_analysis and temporal_system:
            process_temporal_analysis(raycast_data, metrics_result)

        if enable_contract_system and influence_system:
            process_contracts(raycast_data, metrics_result)

    _update_diagnostics(delta_time)
    _last_update_time = current_time

func update_raycast_anchor() -> Dictionary:
    if not raycast_base:
        return {}
    var data: Dictionary = raycast_base.update_raycasts_manual()
    _current_contact_result["raycast_data"] = data
    _current_contact_result["has_contact"] = raycast_base.has_raycast_contact()
    _current_contact_result["timestamp"] = Time.get_ticks_msec() / 1000.0
    _add_to_contact_history(_current_contact_result)
    return data

func process_physical_metrics(raycast_data: Dictionary) -> Dictionary:
    if not metrics_processor:
        return {}
    var metrics = metrics_processor.calculate_metrics(
        raycast_data.get("ray_data", []),
        _current_contact_result.get("metrics", {})
    )
    _current_contact_result["metrics"] = metrics.to_dictionary()
    _current_contact_result["plausibility"] = metrics.is_plausible()

    if enable_debug_visualization and debug_visualizer:
        var avg_pos: Vector3 = _calculate_average_position(raycast_data.get("ray_data", []))
        debug_visualizer.visualize_globally(metrics.to_dictionary(), avg_pos, "metrics")

    return metrics.to_dictionary()

func process_temporal_analysis(raycast_data: Dictionary, metrics_data: Dictionary) -> void:
    if not temporal_system:
        return
    var temporal_result = temporal_system.update_temporal_analysis(
        raycast_data.get("ray_data", []),
        metrics_data
    )
    _current_contact_result["temporal"] = temporal_result
    _current_contact_result["event_score"] = temporal_result.get("event_score", 0.0)

    var events: Array = temporal_result.get("current_events", [])
    for event_data in events:
        _process_temporal_event(event_data)

    _current_contact_result["suggested_response_time"] = temporal_result.get("suggested_response_time", 0.1)

func process_contracts(raycast_data: Dictionary, metrics_data: Dictionary) -> void:
    if not influence_system:
        return
    var ray_data: Array = raycast_data.get("ray_data", [])
    var has_contact: bool = raycast_data.get("has_any_contact", false)

    if not has_contact or ray_data.is_empty():
        if cache_neutral_contracts:
            _handle_neutral_contract_fallback()
        return

    if not _check_rate_limits():
        if cache_neutral_contracts:
            _handle_neutral_contract_fallback()
        return

    var contract_type: Dictionary = _determine_contract_type(ray_data, metrics_data)
    var contract = influence_system.create_contract(
        contract_type.mode,
        contract_type.authority,
        _prepare_contract_data(ray_data, metrics_data)
    )

    if contract:
        var app_result = influence_system.apply_contract(contract, _current_contact_result)
        _current_contact_result["applied_contract"] = app_result
        _current_contact_result["contract_summary"] = contract.get_contract_summary()
        _add_to_contract_history(contract.get_contract_summary())
        contract_applied.emit(contract.get_contract_summary())

        if enable_debug_visualization and debug_visualizer:
            var avg_pos: Vector3 = _calculate_average_position(ray_data)
            debug_visualizer.visualize_globally(contract.get_contract_summary(), avg_pos, "contract")

func process_contact_with_neutral_contract() -> Dictionary:
    var neutral: Dictionary = {
        "mode": 0,
        "authority": 0,
        "confidence": 0.1,
        "influence_weight": 0.1,
        "safety_flags": ["neutral_fallback"],
        "data": {
            "compression": 0.0,
            "normal": Vector3.UP,
            "contact_width": 0.0,
            "stability_score": 0.0
        },
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "is_neutral": true
    }
    var result: Dictionary = _current_contact_result.duplicate()
    result["applied_contract"] = neutral
    result["contract_summary"] = neutral
    result["using_neutral_fallback"] = true

    if cache_neutral_contracts:
        _cache_neutral_contract(neutral)

    return result

# Validação de filosofia
func _validate_philosophy() -> bool:
    if not raycasts_as_optimization:
        push_error("Violação: raycasts devem ser apenas otimização")
        return false
    if not raycasts_never_primary:
        push_error("Violação: raycasts nunca devem ser fonte primária")
        return false
    if max_shader_priority < 1:
        push_warning("Shader deve ter prioridade máxima")
    return true

# API pública de contratos
func create_custom_contract(mode: int, authority: int, data: Dictionary = {}) -> Dictionary:
    if not influence_system:
        return {"error": "InfluenceContractSystem not available"}
    var rate_check = rate_limiter.check_rate_limit("manual", mode, authority)
    if not rate_check.get("can_create", false):
        return {
            "error": "rate_limited",
            "details": rate_check,
            "neutral_alternative": process_contact_with_neutral_contract()
        }
    var contract = influence_system.create_contract(mode, authority, data)
    return contract.get_contract_summary() if contract else {"error": "creation_failed"}

func merge_multiple_contracts(contracts: Array) -> Dictionary:
    if not contract_merger:
        return {"error": "ContractMerger not available"}
    var merge_result = contract_merger.merge_contracts_for_owner("main", contracts)
    return merge_result.merged_contract

func apply_contract_to_contact(contract_data: Dictionary, contact_data: Dictionary = {}) -> Dictionary:
    if not influence_system:
        return {"error": "InfluenceContractSystem not available"}
    var contract = influence_system.create_contract(
        contract_data.get("mode", 0),
        contract_data.get("authority", 0),
        contract_data
    )
    if not contract:
        return {"error": "invalid_contract_data"}
    var target = contact_data if not contact_data.is_empty() else _current_contact_result
    return influence_system.apply_contract(contract, target)

# Histórico
func get_contact_history(count: int = 100) -> Array[Dictionary]:
    if _contact_history.size() > count:
        return _contact_history.slice(-count)
    return _contact_history.duplicate()

func get_contract_history(count: int = 50) -> Array[Dictionary]:
    if _contract_history.size() > count:
        return _contract_history.slice(-count)
    return _contract_history.duplicate()

func clear_history() -> void:
    _contact_history.clear()
    _contract_history.clear()
    if metrics_processor:
        metrics_processor.clear_history()
    if temporal_system:
        temporal_system.clear_history()
    if debug_visualizer:
        debug_visualizer.clear_global_visualization()

# Controle de processamento
func start_processing() -> void:
    _is_processing = true
    set_process(true)

func stop_processing() -> void:
    _is_processing = false
    set_process(false)

func reset_system() -> void:
    stop_processing()
    clear_history()
    _neutral_contract_cache.clear()
    _current_contact_result.clear()
    if metrics_processor:
        metrics_processor.reset_calibration()
    if temporal_system:
        temporal_system.reset_temporal_state()
    _initialize_diagnostics()
    start_processing()
    print("System reset complete")

# Diagnósticos
func get_system_diagnostics() -> Dictionary:
    var diag: Dictionary = {
        "system": _get_system_diagnostics(),
        "components": _get_component_diagnostics(),
        "performance": _get_performance_diagnostics(),
        "philosophy": _get_philosophy_diagnostics(),
        "history": _get_history_diagnostics()
    }
    _system_diagnostics = diag.duplicate()
    diagnostic_updated.emit(diag)
    return diag

# Getters públicos
func is_initialized() -> bool: return _is_initialized
func is_processing() -> bool: return _is_processing
func get_current_contact_result() -> Dictionary: return _current_contact_result.duplicate()
func get_system_version() -> String: return SYSTEM_VERSION
func set_update_rate(rate: float) -> void:
    update_rate = max(rate, 0.0)
    if update_rate > 0.0:
        _update_timer = 0.0
func enable_component(comp: String, enabled: bool) -> void:
    match comp:
        "metrics_processing": enable_metrics_processing = enabled
        "temporal_analysis": enable_temporal_analysis = enabled
        "contract_system": enable_contract_system = enabled
        "debug_visualization":
            enable_debug_visualization = enabled
            if debug_visualizer:
                debug_visualizer.set_enabled(enabled)
        _: push_warning("Unknown component: ", comp)

# Manipuladores de sinais dos componentes
func _on_raycast_data_updated(raw_data: Dictionary) -> void: pass
func _on_contact_started() -> void:
    _current_contact_result["contact_start_time"] = Time.get_ticks_msec() / 1000.0
func _on_contact_ended() -> void:
    _current_contact_result["contact_end_time"] = Time.get_ticks_msec() / 1000.0
    _current_contact_result["contact_duration"] = (
        _current_contact_result["contact_end_time"] -
        _current_contact_result.get("contact_start_time", 0.0)
    )
func _on_contract_created(contract) -> void:
    _system_diagnostics["contracts_created"] = _system_diagnostics.get("contracts_created", 0) + 1
func _on_contract_applied(contract, result: Dictionary) -> void:
    _current_contact_result["last_contract_application"] = result
func _on_rate_limit_check(result: Dictionary) -> void:
    if not result.get("can_create", false):
        _system_diagnostics["rate_limited_events"] = _system_diagnostics.get("rate_limited_events", 0) + 1
func _on_contract_rate_limited(mode: int, authority: int, reason: String) -> void:
    print("Contract rate limited: Mode=%d, Auth=%d, Reason=%s" % [mode, authority, reason])
func _on_contracts_merged(result) -> void:
    _system_diagnostics["contracts_merged"] = _system_diagnostics.get("contracts_merged", 0) + 1
func _on_metrics_calculated(metrics) -> void:
    _current_contact_result["current_metrics"] = metrics.to_dictionary()
func _on_plausibility_changed(old_state: int, new_state: int) -> void:
    _system_diagnostics["plausibility_changes"] = _system_diagnostics.get("plausibility_changes", 0) + 1
func _on_temporal_event_detected(event) -> void:
    _process_temporal_event(event.to_dictionary())
func _on_sudden_impact_detected(intensity: float, position: Vector3) -> void:
    _system_diagnostics["sudden_impacts"] = _system_diagnostics.get("sudden_impacts", 0) + 1
    if enable_debug_visualization and debug_visualizer:
        debug_visualizer.visualize_globally({"intensity": intensity}, position, "impact")
func _on_debug_visualization_updated(element_count: int) -> void:
    if element_count > 100:
        push_warning("High debug element count: ", element_count)

# Funções internas auxiliares
func _process_temporal_event(event_data: Dictionary) -> void:
    if not _current_contact_result.has("temporal_events"):
        _current_contact_result["temporal_events"] = []
    _current_contact_result["temporal_events"].append(event_data)
    if enable_debug_visualization and debug_visualizer:
        var pos: Vector3 = event_data.get("position", Vector3.ZERO)
        if pos == Vector3.ZERO:
            var ray_data = _current_contact_result.get("raycast_data", {}).get("ray_data", [])
            pos = _calculate_average_position(ray_data)
        debug_visualizer.visualize_globally(event_data, pos, "event")

func _handle_neutral_contract_fallback() -> void:
    if cache_neutral_contracts and not _neutral_contract_cache.is_empty():
        var cached = _get_cached_neutral_contract()
        if cached:
            _current_contact_result["applied_contract"] = cached
            _current_contact_result["using_cached_neutral"] = true
            return
    var neutral_result = process_contact_with_neutral_contract()
    _current_contact_result.merge(neutral_result, true)

func _check_rate_limits() -> bool:
    if not rate_limiter:
        return true
    var mode: int = 1
    var authority: int = 2
    if not _current_contact_result.get("plausibility", true):
        mode = 0
        authority = 1
    var check = rate_limiter.check_rate_limit("main", mode, authority)
    return check.get("can_create", false)

func _determine_contract_type(ray_data: Array, metrics_data: Dictionary) -> Dictionary:
    var mode: int = 1
    var authority: int = 2
    var contact_count: int = 0
    for ray in ray_data:
        if ray.get("has_contact", false):
            contact_count += 1

    if contact_count >= 3 and metrics_data.get("plausibility_score", 0.0) > 0.7:
        mode = 2
    elif contact_count < 2 or metrics_data.get("plausibility_score", 0.0) < 0.3:
        mode = 0

    var stability: float = metrics_data.get("stability_score", 0.5)
    var plausibility: float = metrics_data.get("plausibility_score", 0.5)

    if plausibility > 0.8 and stability > 0.7:
        authority = 3
    elif plausibility < 0.4 or stability < 0.3:
        authority = 1
    elif _current_contact_result.get("event_score", 0.0) > 0.7:
        authority = 4

    return {"mode": mode, "authority": authority}

func _prepare_contract_data(ray_data: Array, metrics_data: Dictionary) -> Dictionary:
    var data: Dictionary = {}
    var positions: Array[Vector3] = []
    var normals: Array[Vector3] = []
    var compressions: Array[float] = []
    for ray in ray_data:
        if ray.get("has_contact", false):
            positions.append(ray.get("position", Vector3.ZERO))
            normals.append(ray.get("normal", Vector3.UP))
            compressions.append(ray.get("compression", 0.0))
    data["raycast_data"] = ray_data
    data["contact_positions"] = positions
    data["contact_normals"] = normals
    data["compressions"] = compressions
    data["metrics"] = metrics_data
    if _current_contact_result.has("temporal"):
        data["temporal"] = _current_contact_result.temporal
    var safety: Array[String] = []
    if metrics_data.get("plausibility_state", 0) >= 2:
        safety.append("low_plausibility")
    if _current_contact_result.get("event_score", 0.0) > 0.5:
        safety.append("high_event_score")
    if not safety.is_empty():
        data["safety_flags"] = safety
    return data

func _cache_neutral_contract(contract: Dictionary) -> void:
    var key: String = "neutral_%d" % _neutral_contract_cache.size()
    _neutral_contract_cache[key] = {
        "contract": contract,
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "usage_count": 0
    }
    if _neutral_contract_cache.size() > 10:
        var oldest_key: String = ""
        var oldest_time: float = INF
        for k in _neutral_contract_cache:
            var e = _neutral_contract_cache[k]
            if e.timestamp < oldest_time:
                oldest_time = e.timestamp
                oldest_key = k
        if oldest_key:
            _neutral_contract_cache.erase(oldest_key)

func _get_cached_neutral_contract() -> Dictionary:
    if _neutral_contract_cache.is_empty():
        return {}
    var newest_key: String = ""
    var newest_time: float = 0.0
    for k in _neutral_contract_cache:
        var e = _neutral_contract_cache[k]
        if e.timestamp > newest_time:
            newest_time = e.timestamp
            newest_key = k
    if newest_key.is_empty():
        return {}
    var entry = _neutral_contract_cache[newest_key]
    entry.usage_count += 1
    return entry.contract.duplicate()

func _add_to_contact_history(contact: Dictionary) -> void:
    _contact_history.append(contact.duplicate())
    if _contact_history.size() > metrics_history_size:
        _contact_history.remove_at(0)

func _add_to_contract_history(contract: Dictionary) -> void:
    _contract_history.append(contract.duplicate())
    if _contract_history.size() > event_history_size:
        _contract_history.remove_at(0)

func _calculate_average_position(ray_data: Array) -> Vector3:
    var sum: Vector3 = Vector3.ZERO
    var count: int = 0
    for ray in ray_data:
        if ray.get("has_contact", false):
            sum += ray.get("position", Vector3.ZERO)
            count += 1
    return sum / count if count > 0 else Vector3.ZERO

# Funções de diagnóstico (simplificadas)
func _initialize_diagnostics() -> void:
    _system_diagnostics = {
        "system_version": SYSTEM_VERSION,
        "initialization_time": Time.get_ticks_msec() / 1000.0,
        "update_count": 0,
        "contact_count": 0,
        "contracts_created": 0,
        "contracts_applied": 0,
        "contracts_merged": 0,
        "rate_limited_events": 0,
        "sudden_impacts": 0,
        "plausibility_changes": 0
    }

func _update_diagnostics(delta: float) -> void:
    _system_diagnostics["update_count"] += 1
    if _current_contact_result.get("has_contact", false):
        _system_diagnostics["contact_count"] += 1

func _get_system_diagnostics() -> Dictionary:
    return _system_diagnostics.duplicate()

func _get_component_diagnostics() -> Dictionary:
    var diag: Dictionary = {}
    if raycast_base:
        diag["raycast_base"] = {
            "enabled": true,
            "has_contact": raycast_base.has_raycast_contact()
        }
    if influence_system and enable_contract_system:
        diag["influence_system"] = {"active_contracts": influence_system.get_active_contracts().size()}
    if metrics_processor and enable_metrics_processing:
        diag["metrics_processor"] = {"calibrated": metrics_processor.is_calibrated()}
    if temporal_system and enable_temporal_analysis:
        diag["temporal_system"] = {"in_contact": temporal_system.is_in_contact()}
    if debug_visualizer and enable_debug_visualization:
        diag["debug_visualizer"] = {"enabled": true}
    return diag

func _get_performance_diagnostics() -> Dictionary:
    var uptime: float = Time.get_ticks_msec() / 1000.0 - _system_diagnostics.get("initialization_time", 0.0)
    return {
        "uptime": uptime,
        "updates": _system_diagnostics.get("update_count", 0),
        "updates_per_sec": _system_diagnostics.get("update_count", 0) / uptime if uptime > 0 else 0,
        "contact_history_size": _contact_history.size(),
        "contract_history_size": _contract_history.size(),
        "cache_size": _neutral_contract_cache.size()
    }

func _get_philosophy_diagnostics() -> Dictionary:
    return {
        "raycasts_as_optimization": raycasts_as_optimization,
        "raycasts_never_primary": raycasts_never_primary,
        "max_shader_priority": max_shader_priority,
        "require_safety_contracts": require_safety_contracts,
        "valid": _validate_philosophy()
    }

func _get_history_diagnostics() -> Dictionary:
    return {
        "contact_entries": _contact_history.size(),
        "contract_entries": _contract_history.size()
    }