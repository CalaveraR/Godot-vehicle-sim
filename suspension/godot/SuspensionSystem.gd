class_name SuspensionSystem
extends Node

enum SUSPENSION_TYPE {
    MACPHERSON,
    DOUBLE_WISHBONE,
    MULTILINK,
    SOLID_AXLE,
    PUSH_ROD,
    PULL_ROD,
    AIR
}

enum CoreBackendMode {
    GDSCRIPT,
    RUST,
    SHADOW
}

@export var suspension_type: SUSPENSION_TYPE = SUSPENSION_TYPE.MACPHERSON
@export var base_vertical_stiffness = 150000.0
@export var min_effective_radius = 0.1
@export var tire_radius = 0.3
@export var tire_width = 0.2
@export var motion_ratio = 0.7
@export var unsprung_mass = 25.0
@export var bushing_stiffness = 10000.0
@export var load_transfer_curve: Curve
@export var deformation_x_curve: Curve
@export var deformation_y_curve: Curve
@export var deformation_z_curve: Curve
@export var camber_variation_curve: Curve
@export var caster_variation_curve: Curve
@export var toe_variation_curve: Curve
@export var vertical_stiffness_curve: Curve
@export var dynamic_radius_curve: Curve
@export var relaxation_length_curve: Curve
@export var lateral_deformation_curve: Curve
@export var flat_spot_radius_curve: Curve
@export var response_to_lateral_flex_curve: Curve
@export var response_to_longitudinal_flex_curve: Curve
@export var vibration_absorption_curve: Curve
@export var core_backend_mode: CoreBackendMode = CoreBackendMode.GDSCRIPT
@export var core_shadow_epsilon: float = 0.001
@export var core_enable_snapshot_recording: bool = false
@export var core_snapshot_max_entries: int = 256

var effective_radius = 0.3
var total_load = 0.0
var relaxation_factor = 1.0
var lateral_deformation = 0.0
var deformation = Vector3.ZERO
var dynamic_camber = 0.0
var dynamic_caster = 0.0
var dynamic_toe = 0.0
var tire_induced_deformation = Vector3.ZERO
var absorbed_vibration = 0.0
var raycast: RayCast
var _suspension_core: SuspensionCore = SuspensionCore.new()

var _core_shadow_stats := {
    "ticks": 0,
    "sum_def_delta": 0.0,
    "sum_radius_delta": 0.0,
    "sum_relax_delta": 0.0,
    "sum_lat_delta": 0.0,
    "max_def_delta": 0.0,
    "max_radius_delta": 0.0,
    "max_relax_delta": 0.0,
    "max_lat_delta": 0.0,
}
var _core_snapshots: Array = []

func _ready():
    raycast = RayCast.new()
    raycast.enabled = true
    add_child(raycast)
    reset_raycast()
    configure_curves()

func configure_curves():
    if !load_transfer_curve:
        load_transfer_curve = Curve.new()
        load_transfer_curve.add_point(Vector2(0.0, 0.0))
        load_transfer_curve.add_point(Vector2(10.0, 0.3))
        load_transfer_curve.add_point(Vector2(20.0, 0.6))

func reset_raycast():
    raycast.cast_to = Vector3(0, -tire_radius * 1.5, 0)
    raycast.position = Vector3.ZERO

func get_wheel_loads() -> Array:
    var car = get_parent()
    var loads = [0.0, 0.0, 0.0, 0.0]

    if !car is VehicleBody:
        return loads

    var safe_mass := maxf(float(car.mass), 1e-6)
    var acceleration = car.linear_velocity.length() / safe_mass
    var transfer_factor = load_transfer_curve.interpolate(acceleration)

    loads[0] = safe_mass * 0.25 * (1.0 + transfer_factor)
    loads[1] = safe_mass * 0.25 * (1.0 - transfer_factor)
    loads[2] = safe_mass * 0.25 * (1.0 - transfer_factor)
    loads[3] = safe_mass * 0.25 * (1.0 + transfer_factor)

    return loads

func update_suspension_geometry(load_value: float):
    total_load = load_value

    if deformation_x_curve:
        deformation.x = deformation_x_curve.interpolate(total_load / 10000.0)
    if deformation_y_curve:
        deformation.y = deformation_y_curve.interpolate(total_load / 10000.0)
    if deformation_z_curve:
        deformation.z = deformation_z_curve.interpolate(total_load / 10000.0)

    if camber_variation_curve:
        dynamic_camber = camber_variation_curve.interpolate(deformation.y)
    if caster_variation_curve:
        dynamic_caster = caster_variation_curve.interpolate(deformation.z)
    if toe_variation_curve:
        dynamic_toe = toe_variation_curve.interpolate(deformation.x)

    _run_core_pipeline(total_load)
    update_raycast_direction()

func _run_core_pipeline(load_value: float) -> void:
    match core_backend_mode:
        CoreBackendMode.RUST:
            _run_core_rust_contract(load_value)
        CoreBackendMode.SHADOW:
            _run_core_shadow(load_value)
        _:
            _run_core_gd(load_value)

func _run_core_gd(_load_value: float) -> void:
    apply_elastic_deformation()
    update_effective_radius()
    update_relaxation_length()
    update_lateral_deformation()
    _sanitize_runtime_outputs()

func _run_core_rust_contract(load_value: float) -> void:
    var in_deformation := _safe_vector3(deformation)
    var in_tire_def := _safe_vector3(tire_induced_deformation)
    var deform_out := SuspensionCore.compute_deformation_clamped(in_deformation, in_tire_def)

    var vertical_stiffness_mul := _evaluate_vertical_stiffness_mul(load_value)
    var dynamic_radius_mul := _evaluate_dynamic_radius_mul(load_value)
    var radius_out := SuspensionCore.compute_effective_radius(
        load_value,
        maxf(base_vertical_stiffness, 1e-6),
        maxf(tire_radius, 1e-6),
        min_effective_radius,
        vertical_stiffness_mul,
        dynamic_radius_mul
    )

    var relaxation_curve_value: Variant = null
    if relaxation_length_curve:
        relaxation_curve_value = relaxation_length_curve.interpolate(load_value)

    var lateral_curve_value: Variant = null
    if lateral_deformation_curve:
        var max_load = maxf(base_vertical_stiffness, 1e-6) * (maxf(tire_radius, 1e-6) * 0.3)
        var load_ratio = clampf(load_value / maxf(max_load, 1e-6), 0.0, 1.0)
        lateral_curve_value = lateral_deformation_curve.interpolate(load_ratio)

    var next_deformation := in_deformation
    var next_effective := effective_radius
    if deform_out.has("deformation"):
        next_deformation = _safe_vector3(deform_out.deformation)
    if radius_out.has("effective_radius"):
        next_effective = _safe_float(radius_out.effective_radius, effective_radius)

    var next_relax := SuspensionCore.compute_relaxation_factor(relaxation_factor, relaxation_curve_value)
    var next_lat := SuspensionCore.compute_lateral_deformation(lateral_curve_value)

    if not _all_finite([next_deformation.x, next_deformation.y, next_deformation.z, next_effective, next_relax, next_lat]):
        push_warning("[SUSP_CORE] Invalid rust-contract output; fallback to GDSCRIPT path")
        _run_core_gd(load_value)
        return

    deformation = next_deformation
    effective_radius = clampf(next_effective, min_effective_radius, maxf(tire_radius, 1e-6) * 1.2)
    relaxation_factor = maxf(next_relax, 0.0)
    lateral_deformation = next_lat
    _sanitize_runtime_outputs()

func _run_core_shadow(load_value: float) -> void:
    var deformation_before := deformation
    var effective_before := effective_radius
    var relaxation_before := relaxation_factor
    var lateral_before := lateral_deformation

    _run_core_gd(load_value)
    var gd_deformation := deformation
    var gd_effective := effective_radius
    var gd_relaxation := relaxation_factor
    var gd_lateral := lateral_deformation

    deformation = deformation_before
    effective_radius = effective_before
    relaxation_factor = relaxation_before
    lateral_deformation = lateral_before

    _run_core_rust_contract(load_value)

    var rust_deformation := deformation
    var rust_effective := effective_radius
    var rust_relaxation := relaxation_factor
    var rust_lateral := lateral_deformation

    var def_delta := (gd_deformation - rust_deformation).length()
    var radius_delta := absf(gd_effective - rust_effective)
    var relax_delta := absf(gd_relaxation - rust_relaxation)
    var lat_delta := absf(gd_lateral - rust_lateral)

    _record_shadow_delta(def_delta, radius_delta, relax_delta, lat_delta)
    if core_enable_snapshot_recording:
        _record_core_snapshot(load_value, gd_deformation, rust_deformation, gd_effective, rust_effective, gd_relaxation, rust_relaxation, gd_lateral, rust_lateral)

    if def_delta > core_shadow_epsilon or radius_delta > core_shadow_epsilon or relax_delta > core_shadow_epsilon or lat_delta > core_shadow_epsilon:
        push_warning("[SUSP_SHADOW] delta > epsilon | def=%s radius=%s relax=%s lat=%s" % [def_delta, radius_delta, relax_delta, lat_delta])

    deformation = gd_deformation
    effective_radius = gd_effective
    relaxation_factor = gd_relaxation
    lateral_deformation = gd_lateral

func _record_shadow_delta(def_delta: float, radius_delta: float, relax_delta: float, lat_delta: float) -> void:
    _core_shadow_stats.ticks += 1
    _core_shadow_stats.sum_def_delta += def_delta
    _core_shadow_stats.sum_radius_delta += radius_delta
    _core_shadow_stats.sum_relax_delta += relax_delta
    _core_shadow_stats.sum_lat_delta += lat_delta
    _core_shadow_stats.max_def_delta = maxf(_core_shadow_stats.max_def_delta, def_delta)
    _core_shadow_stats.max_radius_delta = maxf(_core_shadow_stats.max_radius_delta, radius_delta)
    _core_shadow_stats.max_relax_delta = maxf(_core_shadow_stats.max_relax_delta, relax_delta)
    _core_shadow_stats.max_lat_delta = maxf(_core_shadow_stats.max_lat_delta, lat_delta)

func _record_core_snapshot(
    load_value: float,
    gd_deformation: Vector3,
    rust_deformation: Vector3,
    gd_effective: float,
    rust_effective: float,
    gd_relaxation: float,
    rust_relaxation: float,
    gd_lateral: float,
    rust_lateral: float
) -> void:
    var snapshot := {
        "load": load_value,
        "gd_deformation": gd_deformation,
        "rust_deformation": rust_deformation,
        "gd_effective_radius": gd_effective,
        "rust_effective_radius": rust_effective,
        "gd_relaxation": gd_relaxation,
        "rust_relaxation": rust_relaxation,
        "gd_lateral": gd_lateral,
        "rust_lateral": rust_lateral,
        "def_delta": (gd_deformation - rust_deformation).length(),
        "radius_delta": absf(gd_effective - rust_effective),
        "relax_delta": absf(gd_relaxation - rust_relaxation),
        "lat_delta": absf(gd_lateral - rust_lateral),
    }
    _core_snapshots.append(snapshot)
    if _core_snapshots.size() > max(core_snapshot_max_entries, 1):
        _core_snapshots.pop_front()

func get_core_shadow_report() -> Dictionary:
    var ticks := max(1, int(_core_shadow_stats.ticks))
    return {
        "ticks": _core_shadow_stats.ticks,
        "avg_def_delta": _core_shadow_stats.sum_def_delta / float(ticks),
        "avg_radius_delta": _core_shadow_stats.sum_radius_delta / float(ticks),
        "avg_relax_delta": _core_shadow_stats.sum_relax_delta / float(ticks),
        "avg_lat_delta": _core_shadow_stats.sum_lat_delta / float(ticks),
        "max_def_delta": _core_shadow_stats.max_def_delta,
        "max_radius_delta": _core_shadow_stats.max_radius_delta,
        "max_relax_delta": _core_shadow_stats.max_relax_delta,
        "max_lat_delta": _core_shadow_stats.max_lat_delta,
        "snapshot_count": _core_snapshots.size(),
    }

func clear_core_shadow_report() -> void:
    _core_shadow_stats = {
        "ticks": 0,
        "sum_def_delta": 0.0,
        "sum_radius_delta": 0.0,
        "sum_relax_delta": 0.0,
        "sum_lat_delta": 0.0,
        "max_def_delta": 0.0,
        "max_radius_delta": 0.0,
        "max_relax_delta": 0.0,
        "max_lat_delta": 0.0,
    }
    _core_snapshots.clear()

func apply_elastic_deformation():
    deformation += tire_induced_deformation
    deformation = Vector3(
        clampf(deformation.x, -0.1, 0.1),
        clampf(deformation.y, -0.2, 0.0),
        clampf(deformation.z, -0.1, 0.1)
    )

func update_raycast_direction():
    var direction_basis = Basis()
    direction_basis = direction_basis.rotated(Vector3.RIGHT, dynamic_caster)
    direction_basis = direction_basis.rotated(Vector3.UP, dynamic_toe)
    direction_basis = direction_basis.rotated(Vector3.FORWARD, dynamic_camber)
    raycast.cast_to = direction_basis * Vector3.DOWN * tire_radius * 1.5
    raycast.position = deformation

func update_effective_radius():
    var safe_stiffness := maxf(base_vertical_stiffness, 1e-6)
    var deflection = total_load / safe_stiffness
    var max_deflection = maxf(tire_radius, 1e-6) * 0.3
    var deflection_ratio = clampf(deflection / maxf(max_deflection, 1e-6), 0.0, 1.0)

    if vertical_stiffness_curve:
        deflection = total_load / (safe_stiffness * maxf(vertical_stiffness_curve.interpolate(deflection_ratio), 1e-6))

    var base_radius = tire_radius - deflection

    if dynamic_radius_curve:
        var max_load = safe_stiffness * max_deflection
        var load_ratio = clampf(total_load / maxf(max_load, 1e-6), 0.0, 1.0)
        base_radius *= maxf(dynamic_radius_curve.interpolate(load_ratio), 1e-6)

    effective_radius = clampf(base_radius, min_effective_radius, maxf(tire_radius, 1e-6) * 1.2)

func update_relaxation_length():
    if relaxation_length_curve:
        relaxation_factor = maxf(relaxation_length_curve.interpolate(total_load), 0.0)

func update_lateral_deformation():
    if lateral_deformation_curve:
        var max_load = maxf(base_vertical_stiffness, 1e-6) * (maxf(tire_radius, 1e-6) * 0.3)
        var load_ratio = clampf(total_load / maxf(max_load, 1e-6), 0.0, 1.0)
        lateral_deformation = lateral_deformation_curve.interpolate(load_ratio)

func _evaluate_vertical_stiffness_mul(load_value: float) -> float:
    if not vertical_stiffness_curve:
        return 1.0
    var max_deflection = maxf(tire_radius, 1e-6) * 0.3
    var safe_stiffness := maxf(base_vertical_stiffness, 1e-6)
    var deflection = load_value / safe_stiffness
    var ratio = clampf(deflection / maxf(max_deflection, 1e-6), 0.0, 1.0)
    return maxf(vertical_stiffness_curve.interpolate(ratio), 1e-6)

func _evaluate_dynamic_radius_mul(load_value: float) -> float:
    if not dynamic_radius_curve:
        return 1.0
    var max_load = maxf(base_vertical_stiffness, 1e-6) * (maxf(tire_radius, 1e-6) * 0.3)
    var ratio = clampf(load_value / maxf(max_load, 1e-6), 0.0, 1.0)
    return maxf(dynamic_radius_curve.interpolate(ratio), 1e-6)

func _sanitize_runtime_outputs() -> void:
    deformation = _safe_vector3(deformation)
    effective_radius = clampf(_safe_float(effective_radius, min_effective_radius), min_effective_radius, maxf(tire_radius, 1e-6) * 1.2)
    relaxation_factor = maxf(_safe_float(relaxation_factor, 0.0), 0.0)
    lateral_deformation = _safe_float(lateral_deformation, 0.0)

func _safe_vector3(value: Vector3) -> Vector3:
    return Vector3(
        _safe_float(value.x, 0.0),
        _safe_float(value.y, 0.0),
        _safe_float(value.z, 0.0)
    )

func _safe_float(value: float, fallback: float) -> float:
    if is_nan(value) or is_inf(value):
        return fallback
    return value

func _all_finite(values: Array) -> bool:
    for v in values:
        var f := float(v)
        if is_nan(f) or is_inf(f):
            return false
    return true

# Funções de acesso
func get_effective_radius() -> float:
    return effective_radius

func get_dynamic_camber() -> float:
    return dynamic_camber

func get_dynamic_toe() -> float:
    return dynamic_toe
