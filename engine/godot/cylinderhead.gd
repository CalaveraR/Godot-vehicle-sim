class_name CylinderHead
extends Node

# ======================
# Signals (interface pública)
# ======================
signal valve_event(cylinder: int, valve_type: String, state: bool, angle: float)
signal combustion_event(cylinder: int, crank_angle: float)
signal config_warning(message: String)

# ======================
# Configuração
# ======================
var engine_type: int = EngineConfig.EngineType.PISTON
var _number_of_cylinders: int = 4
var number_of_cylinders: int:
    get: return _number_of_cylinders
    set(value):
        if _number_of_cylinders != value:
            _number_of_cylinders = value
            init_state_arrays()
var max_vvt_advance: float = 40.0
var min_vvt_advance: float = 0.0
var redline_rpm: float = 22000.0

# Curvas
var _vvt_advance_curve: Curve
var vvt_advance_curve: Curve:
    get: return _vvt_advance_curve
    set(value):
        _vvt_advance_curve = value
        _cache_curve(_vvt_advance_curve)

var _volumetric_efficiency_curve: Curve
var volumetric_efficiency_curve: Curve:
    get: return _volumetric_efficiency_curve
    set(value):
        _volumetric_efficiency_curve = value
        _ve_cache_bucket = -1
        _cache_curve(_volumetric_efficiency_curve)

var _throttle_vvt_influence_curve: Curve
var throttle_vvt_influence_curve: Curve:
    get: return _throttle_vvt_influence_curve
    set(value):
        _throttle_vvt_influence_curve = value
        _cache_curve(_throttle_vvt_influence_curve)

var _intake_cam_curve: Curve          # Perfil de came de admissão (x = ângulo normalizado 0..1, y = lift)
var intake_cam_curve: Curve:
    get: return _intake_cam_curve
    set(value):
        _intake_cam_curve = value
        _cache_curve(_intake_cam_curve)

var _exhaust_cam_curve: Curve         # Perfil de came de escape (x = ângulo normalizado 0..1, y = lift)
var exhaust_cam_curve: Curve:
    get: return _exhaust_cam_curve
    set(value):
        _exhaust_cam_curve = value
        _cache_curve(_exhaust_cam_curve)

# ======================
# Cache (VE)
# ======================
# Usa bucket inteiro para determinismo e custo mínimo.
# Cada bucket corresponde a um passo de 0.001 no rpm_normalized (0..1 ⇒ 0..1000).
var _ve_cache_value: float = 0.85
var _ve_cache_bucket: int = -1  # último bucket amostrado

var _warned_missing_cam_curves: bool = false

const VVT_RESPONSE_RATE: float = 5.0

var _curve_meta: Dictionary = {}  # map int(instance_id) -> [min_x, max_x, y_at_min, y_at_max]

func get_volumetric_efficiency(rpm_normalized: float) -> float:
    var t = clamp(rpm_normalized, 0.0, 1.0)
    var b := int(t * 1000.0 + 0.5)
    if b == _ve_cache_bucket:
        return _ve_cache_value
    _ve_cache_bucket = b
    _ve_cache_value = sample_curve_safe(volumetric_efficiency_curve, float(b) / 1000.0, 0.85)
    return _ve_cache_value
# Estado
var current_vvt_advance: float = 0.0
var volumetric_efficiency: float = 0.85
var intake_valve_open: PackedByteArray = PackedByteArray()
var exhaust_valve_open: PackedByteArray = PackedByteArray()
var exhaust_valve_lift: PackedFloat32Array = PackedFloat32Array()
var exhaust_valve_open_angle: PackedFloat32Array = PackedFloat32Array()

var _cyl_count_cached: int = 0
var _cyl_phase_deg: PackedFloat32Array = PackedFloat32Array()  # precomputed phases

var _emit_valve_events: bool = true  # toggle to disable signal emission for performance

# Referência (com backing field para evitar recursão no setter)
var _engine: Engine = null
var engine: Engine:
    get:
        return _engine
    set(value):
        _engine = value
        _warned_missing_engine = false
        _update_engine_properties()   # Sincroniza tipo e redline com a nova engine

# ======================
# PID opcional (VVT)
# ======================
var use_vvt_pid: bool = false
var pid_kp: float = 2.0
var pid_ki: float = 0.5
var pid_kd: float = 0.1
var pid_integral: float = 0.0
var pid_prev_error: float = 0.0

# Controle de warnings únicos
var _warned_missing_engine: bool = false
var _warned_missing_crankshaft: bool = false

# ======================
# Configuração e validação
# ======================
func configure(cylinders: int, max_vvt: float, min_vvt: float,
               vvt_curve: Curve, ve_curve: Curve, throttle_curve: Curve = null,
               engine_ref: Engine = null):
    """Método de configuração direta (compatível com o segundo script)."""
    number_of_cylinders = cylinders
    max_vvt_advance = max_vvt
    min_vvt_advance = min_vvt
    vvt_advance_curve = vvt_curve
    volumetric_efficiency_curve = ve_curve
    throttle_vvt_influence_curve = throttle_curve if throttle_curve else create_default_throttle_curve()

    if engine_ref:
        engine = engine_ref  # Usa o setter, que já chama _update_engine_properties
    else:
        # Se não veio engine_ref, ainda assim tenta atualizar as propriedades da engine atual
        _update_engine_properties()

    # Garantir que engine_type seja um valor válido do enum
    if engine_type != EngineConfig.EngineType.PISTON and engine_type != EngineConfig.EngineType.WANKEL:
        engine_type = EngineConfig.EngineType.PISTON
        emit_signal("config_warning", "Tipo de motor inválido, usando PISTON")

    init_state_arrays()
    # Clear VE cache so future samples use updated curve
    _ve_cache_bucket = -1
    validate_config()

func _update_engine_properties():
    """Extrai engine_type e redline_rpm da engine atual, se disponível."""
    if not _engine:
        return
    var t = _engine.get("engine_type")
    if t != null:
        if typeof(t) == TYPE_STRING:
            engine_type = EngineConfig.EngineType.WANKEL if t == "WANKEL" else EngineConfig.EngineType.PISTON
        elif typeof(t) == TYPE_INT:
            engine_type = t
    var r = _engine.get("redline_rpm")
    if r != null:
        redline_rpm = r

func configure_from_json(file_path: String):
    if not FileAccess.file_exists(file_path):
        configure_defaults()
        return

    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        configure_defaults()
        return

    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) == TYPE_DICTIONARY:
        load_config_from_dict(data)
    else:
        push_warning("CylinderHead: erro ao parsear JSON ou formato inválido, usando defaults")
        configure_defaults()

func load_config_from_dict(data: Dictionary):
    var type_str = data.get("engine_type", "PISTON")
    match type_str:
        "PISTON":
            engine_type = EngineConfig.EngineType.PISTON
        "WANKEL":
            engine_type = EngineConfig.EngineType.WANKEL
        _:
            engine_type = EngineConfig.EngineType.PISTON
            emit_signal("config_warning", "Tipo de motor desconhecido, usando PISTON")

    number_of_cylinders = data.get("cylinders", 4)
    max_vvt_advance = data.get("max_vvt", 40.0)
    min_vvt_advance = data.get("min_vvt", 0.0)
    redline_rpm = data.get("redline_rpm", 7000.0)

    use_vvt_pid = data.get("use_vvt_pid", false)
    pid_kp = data.get("pid_kp", 2.0)
    pid_ki = data.get("pid_ki", 0.5)
    pid_kd = data.get("pid_kd", 0.1)

    vvt_advance_curve = load_curve(data.get("vvt_curve", []))
    volumetric_efficiency_curve = load_curve(data.get("ve_curve", []))
    throttle_vvt_influence_curve = load_curve(data.get("throttle_curve", []), true)

    # Carregar perfis de came (agora como Curve, com x normalizado)
    intake_cam_curve = load_cam_curve(data.get("intake_cam", []))
    exhaust_cam_curve = load_cam_curve(data.get("exhaust_cam", []))

    init_state_arrays()
    validate_config()

func configure_defaults():
    engine_type = EngineConfig.EngineType.PISTON
    vvt_advance_curve = create_default_vvt_curve()
    volumetric_efficiency_curve = create_default_ve_curve()
    throttle_vvt_influence_curve = create_default_throttle_curve()
    create_default_cam_curves()
    init_state_arrays()
    validate_config()

func validate_config() -> bool:
    var valid = true

    # --- Número de cilindros / rotores ---
    if number_of_cylinders <= 0:
        number_of_cylinders = 1
        emit_signal("config_warning", "CylinderHead: number_of_cylinders <= 0, ajustado para 1")
        valid = false
    elif number_of_cylinders > 32:
        emit_signal("config_warning", "CylinderHead: número de cilindros/rotores muito alto (%d), limitado a 32" % number_of_cylinders)
        number_of_cylinders = 32
        valid = false

    # --- Faixa de VVT ---
    if min_vvt_advance < -30 or min_vvt_advance > 90:
        emit_signal("config_warning", "CylinderHead: min_vvt_advance fora da faixa (-30 a 90), ajustado")
        min_vvt_advance = clamp(min_vvt_advance, -30, 90)
        valid = false
    if max_vvt_advance < -30 or max_vvt_advance > 90:
        emit_signal("config_warning", "CylinderHead: max_vvt_advance fora da faixa (-30 a 90), ajustado")
        max_vvt_advance = clamp(max_vvt_advance, -30, 90)
        valid = false
    if min_vvt_advance > max_vvt_advance:
        var temp = min_vvt_advance
        min_vvt_advance = max_vvt_advance
        max_vvt_advance = temp
        emit_signal("config_warning", "CylinderHead: min_vvt_advance > max_vvt_advance, valores invertidos")

    # --- RPM ---
    if redline_rpm < 600 or redline_rpm > 22000:
        emit_signal("config_warning", "CylinderHead: redline_rpm fora do intervalo (600–22000), ajustado")
        redline_rpm = clamp(redline_rpm, 600, 22000)
        valid = false

    # --- PID ---
    if pid_kp < 0 or pid_kp > 100:
        emit_signal("config_warning", "CylinderHead: pid_kp fora da faixa (0–100), ajustado")
        pid_kp = clamp(pid_kp, 0, 100)
        valid = false
    if pid_ki < 0 or pid_ki > 100:
        emit_signal("config_warning", "CylinderHead: pid_ki fora da faixa (0–100), ajustado")
        pid_ki = clamp(pid_ki, 0, 100)
        valid = false
    if pid_kd < 0 or pid_kd > 100:
        emit_signal("config_warning", "CylinderHead: pid_kd fora da faixa (0–100), ajustado")
        pid_kd = clamp(pid_kd, 0, 100)
        valid = false

    # --- Curva de VE ---
    if not volumetric_efficiency_curve or volumetric_efficiency_curve.get_point_count() == 0:
        volumetric_efficiency_curve = create_default_ve_curve()
        emit_signal("config_warning", "CylinderHead: VE curve ausente, fallback aplicado")
        valid = false
    else:
        if not _curve_has_span(volumetric_efficiency_curve):
            volumetric_efficiency_curve = create_default_ve_curve()
            emit_signal("config_warning", "CylinderHead: VE curve sem variação em X, fallback aplicado")
            valid = false
        else:
            # Clamp valores de VE (0–1.3) e verificar domínio x
            for i in range(volumetric_efficiency_curve.get_point_count()):
                var pt = volumetric_efficiency_curve.get_point_position(i)
                if pt.x < 0 or pt.x > 1:
                    emit_signal("config_warning", "CylinderHead: ponto de VE com x fora de [0,1] (x=%.2f)" % pt.x)
                    valid = false
                if pt.y < 0 or pt.y > 1.3:
                    var clamped_y = clamp(pt.y, 0.0, 1.3)
                    if not is_equal_approx(pt.y, clamped_y):
                        emit_signal("config_warning", "CylinderHead: VE curve com valor fora de 0–1.3, ajustado")
                        volumetric_efficiency_curve.set_point_position(i, Vector2(pt.x, clamped_y))
                        valid = false

    # --- Curvas de VVT e throttle ---
    if not vvt_advance_curve or vvt_advance_curve.get_point_count() == 0:
        vvt_advance_curve = create_default_vvt_curve()
        emit_signal("config_warning", "CylinderHead: VVT curve ausente, fallback aplicado")
        valid = false
    else:
        if not _curve_has_span(vvt_advance_curve):
            vvt_advance_curve = create_default_vvt_curve()
            emit_signal("config_warning", "CylinderHead: VVT curve sem variação em X, fallback aplicado")
            valid = false
        else:
            for i in range(vvt_advance_curve.get_point_count()):
                var pt = vvt_advance_curve.get_point_position(i)
                if pt.x < 0 or pt.x > 1:
                    emit_signal("config_warning", "CylinderHead: ponto de VVT com x fora de [0,1] (x=%.2f)" % pt.x)
                    valid = false

    if not throttle_vvt_influence_curve or throttle_vvt_influence_curve.get_point_count() == 0:
        throttle_vvt_influence_curve = create_default_throttle_curve()
        emit_signal("config_warning", "CylinderHead: throttle influence curve ausente, fallback aplicado")
        valid = false
    else:
        if not _curve_has_span(throttle_vvt_influence_curve):
            throttle_vvt_influence_curve = create_default_throttle_curve()
            emit_signal("config_warning", "CylinderHead: throttle influence curve sem variação em X, fallback aplicado")
            valid = false
        else:
            for i in range(throttle_vvt_influence_curve.get_point_count()):
                var pt = throttle_vvt_influence_curve.get_point_position(i)
                if pt.x < 0 or pt.x > 1:
                    emit_signal("config_warning", "CylinderHead: ponto de throttle influence com x fora de [0,1] (x=%.2f)" % pt.x)
                    valid = false

    # --- Perfis de came ---
    if not intake_cam_curve or not exhaust_cam_curve:
        emit_signal("config_warning", "CylinderHead: Perfis de came ausentes, aplicando defaults")
        create_default_cam_curves()
        valid = false
    else:
        # Validar span
        if not _curve_has_span(intake_cam_curve) or not _curve_has_span(exhaust_cam_curve):
            emit_signal("config_warning", "CylinderHead: Perfil de came sem variação em X, aplicando defaults")
            create_default_cam_curves()
            valid = false
        else:
            for curve in [intake_cam_curve, exhaust_cam_curve]:
                for i in range(curve.get_point_count()):
                    var pt = curve.get_point_position(i)
                    if pt.x < 0 or pt.x > 1:
                        emit_signal("config_warning", "CylinderHead: Ponto de came com x fora de [0,1] (x=%.2f)" % pt.x)
                        valid = false
                    if pt.y < 0 or pt.y > 1.5:
                        emit_signal("config_warning", "CylinderHead: lift fora do intervalo esperado (y=%.2f)" % pt.y)
                        valid = false

    _ve_cache_bucket = -1
    # Cache metadata for curves to speed up sampling at runtime
    _cache_all_curves()
    return valid

func _curve_has_span(curve: Curve) -> bool:
    """Retorna true se a curva tem pontos com X diferentes (variação mensurável)."""
    if not curve or curve.get_point_count() < 2:
        return false
    var min_x := INF
    var max_x := -INF
    for i in range(curve.get_point_count()):
        var x = curve.get_point_position(i).x
        min_x = min(min_x, x)
        max_x = max(max_x, x)
    return (max_x - min_x) > 0.0001

func _compute_curve_meta(curve: Curve) -> Array:
    var min_x := INF
    var max_x := -INF
    var y_at_min := 0.0
    var y_at_max := 0.0
    if not curve or curve.get_point_count() == 0:
        return [min_x, max_x, y_at_min, y_at_max]
    for i in range(curve.get_point_count()):
        var pt = curve.get_point_position(i)
        if pt.x < min_x:
            min_x = pt.x
            y_at_min = pt.y
        if pt.x > max_x:
            max_x = pt.x
            y_at_max = pt.y
    return [min_x, max_x, y_at_min, y_at_max]

func _cache_curve(curve: Curve) -> void:
    if not curve:
        return
    var id := curve.get_instance_id()
    _curve_meta[id] = _compute_curve_meta(curve)

func _cache_all_curves() -> void:
    _curve_meta.clear()
    _cache_curve(volumetric_efficiency_curve)
    _cache_curve(vvt_advance_curve)
    _cache_curve(throttle_vvt_influence_curve)
    _cache_curve(intake_cam_curve)
    _cache_curve(exhaust_cam_curve)

# ======================
# Sampler seguro para curvas
# ======================
func sample_curve_safe(curve: Curve, t: float, default: float = 0.0, clamp_to_endpoints: bool = true) -> float:
    """Amostra uma curva de forma segura.
       Se clamp_to_endpoints for true (padrão), fora do intervalo real retorna o valor do ponto mais próximo.
       Se false, retorna o valor default (usado para cames, onde queremos lift zero fora da janela)."""
    if not curve or curve.get_point_count() == 0:
        return default

    t = clamp(t, 0.0, 1.0)

    var id := curve.get_instance_id()
    if _curve_meta.has(id):
        var meta = _curve_meta[id]
        var min_x = meta[0]
        var max_x = meta[1]
        var y_at_min = meta[2]
        var y_at_max = meta[3]

        if t <= min_x:
            return y_at_min if clamp_to_endpoints else default
        if t >= max_x:
            return y_at_max if clamp_to_endpoints else default
        return curve.interpolate(t)

    # Fallback: compute endpoints on the fly (keeps compatibility)
    var min_x := INF
    var max_x := -INF
    var y_at_min := 0.0
    var y_at_max := 0.0
    for i in range(curve.get_point_count()):
        var pt = curve.get_point_position(i)
        if pt.x < min_x:
            min_x = pt.x
            y_at_min = pt.y
        if pt.x > max_x:
            max_x = pt.x
            y_at_max = pt.y

    if t <= min_x:
        return y_at_min if clamp_to_endpoints else default
    if t >= max_x:
        return y_at_max if clamp_to_endpoints else default

    return curve.interpolate(t)

# ======================
# Inicialização dos arrays de estado
# ======================
func init_state_arrays():
    var n := number_of_cylinders
    intake_valve_open.resize(n)
    exhaust_valve_open.resize(n)
    exhaust_valve_lift.resize(n)
    exhaust_valve_open_angle.resize(n)

    _cyl_phase_deg.resize(n)
    var angle_per := 720.0 / float(max(n, 1))
    for i in range(n):
        intake_valve_open[i] = 0
        exhaust_valve_open[i] = 0
        exhaust_valve_lift[i] = 0.0
        exhaust_valve_open_angle[i] = -1.0
        _cyl_phase_deg[i] = float(i) * angle_per

    _cyl_count_cached = n

# ======================
# Defaults refinados
# ======================
static func create_default_vvt_curve() -> Curve:
    var curve = Curve.new()
    curve.add_point(Vector2(0.0, 0.0))
    curve.add_point(Vector2(1.0, 1.0))
    return curve

static func create_default_ve_curve() -> Curve:
    var curve = Curve.new()
    curve.add_point(Vector2(0.0, 0.75))
    curve.add_point(Vector2(0.3, 0.90))
    curve.add_point(Vector2(0.6, 0.95))
    curve.add_point(Vector2(0.9, 0.85))
    curve.add_point(Vector2(1.0, 0.80))
    return curve

static func create_default_throttle_curve() -> Curve:
    var curve = Curve.new()
    curve.add_point(Vector2(0.0, 0.7))
    curve.add_point(Vector2(0.5, 1.0))
    curve.add_point(Vector2(1.0, 1.3))
    return curve

func create_default_cam_curves():
    # Perfis de came: eixo X normalizado (ângulo/720), Y = lift (0..1)
    intake_cam_curve = Curve.new()
    intake_cam_curve.add_point(Vector2(340.0 / 720.0, 0.0))
    intake_cam_curve.add_point(Vector2(360.0 / 720.0, 0.5))
    intake_cam_curve.add_point(Vector2(400.0 / 720.0, 1.0))
    intake_cam_curve.add_point(Vector2(480.0 / 720.0, 0.0))

    exhaust_cam_curve = Curve.new()
    exhaust_cam_curve.add_point(Vector2(140.0 / 720.0, 0.0))
    exhaust_cam_curve.add_point(Vector2(180.0 / 720.0, 0.7))
    exhaust_cam_curve.add_point(Vector2(220.0 / 720.0, 1.0))
    exhaust_cam_curve.add_point(Vector2(280.0 / 720.0, 0.0))

# ======================
# Helpers
# ======================
func load_curve(points: Array, clamp_to_one: bool=false) -> Curve:
    var curve = Curve.new()
    for p in points:
        if p.has("x") and p.has("y"):
            var x = float(p["x"])
            var y = float(p["y"])
            if clamp_to_one:
                y = clamp(y, 0.0, 1.0)
            # A validação de domínio será feita centralizadamente no validate_config
            curve.add_point(Vector2(x, y))
    return curve

func load_cam_curve(points: Array) -> Curve:
    """Carrega uma curva de came a partir de pontos em graus (converte para normalizado)."""
    var curve = Curve.new()
    for p in points:
        if p.has("x") and p.has("y"):
            var x_deg = p["x"]
            var y = p["y"]
            var x_norm = float(x_deg) / 720.0
            curve.add_point(Vector2(x_norm, y))
    return curve

# ======================
# Runtime
# ======================
func update(delta: float, rpm: float, throttle: float):
    """
    Atualiza o estado da cabeça do cilindro.
    delta: tempo em segundos
    rpm: rotações por minuto do motor
    throttle: posição do acelerador (0 a 1)
    """
    if not _engine:
        if not _warned_missing_engine:
            _warned_missing_engine = true
            emit_signal("config_warning", "CylinderHead: Nenhuma referência de Engine definida, update ignorado")
            push_warning("CylinderHead: Engine não definida!")
        return

    throttle = clamp(throttle, 0.0, 1.0)
    var safe_redline = max(redline_rpm, 1.0)
    var rpm_normalized = clamp(rpm / safe_redline, 0.0, 1.0)

    if engine_type == EngineConfig.EngineType.PISTON:
        update_vvt_advance(delta, rpm_normalized, throttle)
        # Ensure crankshaft exists before using it (use get() instead of has())
        var cs = null
        if _engine:
            cs = _engine.get("crankshaft")
        if cs != null and cs.has_method("get_angle"):
            _warned_missing_crankshaft = false
            update_valve_states(cs.get_angle())
        else:
            if not _warned_missing_crankshaft:
                _warned_missing_crankshaft = true
                emit_signal("config_warning", "CylinderHead: crankshaft ausente na Engine, update de válvulas ignorado")
        volumetric_efficiency = get_volumetric_efficiency(rpm_normalized)

    elif engine_type == EngineConfig.EngineType.WANKEL:
        # Wankel uses rotor-based combustion events; ensure crankshaft exists
        var cs = null
        if _engine:
            cs = _engine.get("crankshaft")
        if cs == null or not cs.has_method("get_angle"):
            if not _warned_missing_crankshaft:
                _warned_missing_crankshaft = true
                emit_signal("config_warning", "CylinderHead: crankshaft ausente na Engine, eventos WANKEL ignorados")
            return
        volumetric_efficiency = get_volumetric_efficiency(rpm_normalized)
        var rotor_count = get_rotor_count()
        if rotor_count <= 0:
            return
        var angle_per_rotor = 360.0 / rotor_count
        var base_angle = cs.get_angle()
        for r in range(rotor_count):
            var rotor_angle = fmod(base_angle + r * angle_per_rotor, 360.0)
            emit_signal("combustion_event", r, rotor_angle)

func update_vvt_advance(delta: float, rpm_normalized: float, throttle: float):
    if engine_type != EngineConfig.EngineType.PISTON:
        return

    var target_advance = 0.0
    if vvt_advance_curve:
        var target_factor = clamp(sample_curve_safe(vvt_advance_curve, rpm_normalized, 0.0), 0.0, 1.0)
        var throttle_factor = clamp(sample_curve_safe(throttle_vvt_influence_curve, throttle, 1.0), 0.0, 2.0)
        target_advance = target_factor * max_vvt_advance * throttle_factor
    else:
        target_advance = lerp(min_vvt_advance, max_vvt_advance, rpm_normalized)

    if use_vvt_pid:
        var error = target_advance - current_vvt_advance
        pid_integral += error * delta

        var max_integral = (max_vvt_advance - min_vvt_advance) / max(pid_ki, 0.001)
        pid_integral = clamp(pid_integral, -max_integral, max_integral)

        var safe_delta = max(delta, 0.000001)
        var derivative = (error - pid_prev_error) / safe_delta
        var output = pid_kp * error + pid_ki * pid_integral + pid_kd * derivative

        var max_change = 100.0 * safe_delta
        output = clamp(output, -max_change, max_change)

        pid_prev_error = error
        current_vvt_advance = clamp(current_vvt_advance + output, min_vvt_advance, max_vvt_advance)
    else:
        # Limitar delta para evitar saltos muito grandes em pausas/hitches
        var dt = min(delta, 0.05)
        current_vvt_advance = lerp(current_vvt_advance, clamp(target_advance, min_vvt_advance, max_vvt_advance), dt * VVT_RESPONSE_RATE)

func update_valve_states(crank_angle: float):
    if engine_type != EngineConfig.EngineType.PISTON:
        return

    if not intake_cam_curve or not exhaust_cam_curve:
        if not _warned_missing_cam_curves:
            _warned_missing_cam_curves = true
            emit_signal("config_warning", "CylinderHead: Perfis de came ausentes em runtime, update de válvulas ignorado")
        return

    var n := min(_cyl_count_cached, intake_valve_open.size())
    n = min(n, _cyl_phase_deg.size())
    if n <= 0:
        return

    for i in range(n):
        var angle = fmod(crank_angle - _cyl_phase_deg[i] + 720.0, 720.0)
        var angle_norm = angle / 720.0  # already in [0,1]

        # Para cames, queremos lift zero fora da janela real -> clamp_to_endpoints = false
        var intake_lift = sample_curve_safe(intake_cam_curve, angle_norm, 0.0, false)
        var exhaust_lift = sample_curve_safe(exhaust_cam_curve, angle_norm, 0.0, false)

        var prev_intake := intake_valve_open[i]
        var prev_exhaust := exhaust_valve_open[i]

        var new_intake := 1 if intake_lift > 0.0 else 0
        var new_exhaust := 1 if exhaust_lift > 0.0 else 0

        intake_valve_open[i] = new_intake
        exhaust_valve_open[i] = new_exhaust

        if _emit_valve_events and new_intake != prev_intake:
            emit_signal("valve_event", i, "intake", new_intake == 1, angle)
        if _emit_valve_events and new_exhaust != prev_exhaust:
            emit_signal("valve_event", i, "exhaust", new_exhaust == 1, angle)

        if new_exhaust == 1:
            exhaust_valve_lift[i] = exhaust_lift
            exhaust_valve_open_angle[i] = angle
        else:
            exhaust_valve_lift[i] = 0.0
            exhaust_valve_open_angle[i] = -1.0

# ======================
# Consultas
# ======================
func is_intake_valve_open(cylinder: int) -> bool:
    if engine_type != EngineConfig.EngineType.PISTON:
        return false
    if cylinder < 0 or cylinder >= _cyl_count_cached:
        return false
    return intake_valve_open[cylinder] == 1

func is_exhaust_valve_open(cylinder: int) -> bool:
    if engine_type != EngineConfig.EngineType.PISTON:
        return false
    if cylinder < 0 or cylinder >= _cyl_count_cached:
        return false
    return exhaust_valve_open[cylinder] == 1

func get_exhaust_valve_lift(cylinder: int) -> float:
    if cylinder < 0 or cylinder >= _cyl_count_cached:
        return 0.0
    return exhaust_valve_lift[cylinder]

func get_exhaust_valve_open_angle(cylinder: int) -> float:
    if cylinder < 0 or cylinder >= _cyl_count_cached:
        return 0.0
    return exhaust_valve_open_angle[cylinder]

func get_exhaust_valve_open_percent(cylinder: int) -> float:
    return clamp(get_exhaust_valve_lift(cylinder), 0.0, 1.0)

# ======================
# Consultas Wankel refinadas
# ======================
func is_combustion_chamber_sealed(rotor: int) -> bool:
    if engine_type != EngineConfig.EngineType.WANKEL or not _engine:
        return false
    var rotor_count = get_rotor_count()
    if rotor_count <= 0:
        return false
    var phase = (360.0 / rotor_count) * rotor
    var cs = null
    if _engine:
        cs = _engine.get("crankshaft")
    if cs == null or not cs.has_method("get_angle"):
        return false
    var angle = fmod(cs.get_angle() + phase, 360.0)
    return angle > 30.0 and angle < 150.0

func get_rotor_seal_state(rotor: int) -> Dictionary:
    if engine_type != EngineConfig.EngineType.WANKEL or not _engine:
        return {"sealed": false, "angle": 0.0}
    var rotor_count = get_rotor_count()
    if rotor_count <= 0:
        return {"sealed": false, "angle": 0.0}
    var phase = (360.0 / rotor_count) * rotor
    var cs = null
    if _engine:
        cs = _engine.get("crankshaft")
    if cs == null or not cs.has_method("get_angle"):
        return {"sealed": false, "angle": 0.0}
    var angle = fmod(cs.get_angle() + phase, 360.0)
    var sealed = angle > 30.0 and angle < 150.0
    var sealing_percent = 0.0
    if sealed:
        sealing_percent = clamp((angle - 30.0) / 120.0, 0.0, 1.0)
    return {
        "sealed": sealed,
        "angle": angle,
        "sealing_percent": sealing_percent
    }

func get_rotor_count() -> int:
    return number_of_cylinders if engine_type == EngineConfig.EngineType.WANKEL else 0

# ======================
# Ciclo de vida
# ======================
func _ready():
    if not volumetric_efficiency_curve:
        configure_defaults()
    else:
        validate_config()

func _exit_tree():
    pass


