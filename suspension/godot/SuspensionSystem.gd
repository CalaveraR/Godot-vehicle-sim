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
    
    # Configurar outras curvas com valores padrão se necessário

func reset_raycast():
    raycast.cast_to = Vector3(0, -tire_radius * 1.5, 0)
    raycast.position = Vector3.ZERO

func get_wheel_loads() -> Array:
    var car = get_parent()
    var loads = [0.0, 0.0, 0.0, 0.0]
    
    if !car is VehicleBody:
        return loads
    
    # Cálculo de transferência de peso com curva
    var acceleration = car.linear_velocity.length() / car.mass
    var transfer_factor = load_transfer_curve.interpolate(acceleration)
    
    # Distribuição com transferência dinâmica
    loads[0] = car.mass * 0.25 * (1.0 + transfer_factor)  # FL
    loads[1] = car.mass * 0.25 * (1.0 - transfer_factor)  # FR
    loads[2] = car.mass * 0.25 * (1.0 - transfer_factor)  # RL
    loads[3] = car.mass * 0.25 * (1.0 + transfer_factor)  # RR
    
    return loads

func update_suspension_geometry(total_load: float):
    # Usar curvas para deformações
    if deformation_x_curve: 
        deformation.x = deformation_x_curve.interpolate(total_load / 10000.0)
    if deformation_y_curve: 
        deformation.y = deformation_y_curve.interpolate(total_load / 10000.0)
    if deformation_z_curve: 
        deformation.z = deformation_z_curve.interpolate(total_load / 10000.0)
    
    # Atualizar ângulos dinâmicos
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
            _run_core_rust_stub(load_value)
        CoreBackendMode.SHADOW:
            _run_core_shadow(load_value)
        _:
            _run_core_gd(load_value)

func _run_core_gd(_load_value: float) -> void:
    apply_elastic_deformation()
    update_effective_radius()
    update_relaxation_length()
    update_lateral_deformation()

func _run_core_rust_stub(_load_value: float) -> void:
    # Ponte Rust real será conectada via GDExtension/FFI, mantendo este orquestrador como autoridade.
    _run_core_gd(_load_value)

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

    _run_core_rust_stub(load_value)

    var def_delta := (gd_deformation - deformation).length()
    var radius_delta := absf(gd_effective - effective_radius)
    var relax_delta := absf(gd_relaxation - relaxation_factor)
    var lat_delta := absf(gd_lateral - lateral_deformation)

    if def_delta > core_shadow_epsilon or radius_delta > core_shadow_epsilon or relax_delta > core_shadow_epsilon or lat_delta > core_shadow_epsilon:
        push_warning("[SUSP_SHADOW] delta > epsilon | def=%s radius=%s relax=%s lat=%s" % [def_delta, radius_delta, relax_delta, lat_delta])

    deformation = gd_deformation
    effective_radius = gd_effective
    relaxation_factor = gd_relaxation
    lateral_deformation = gd_lateral

func apply_elastic_deformation():
    deformation += tire_induced_deformation
    deformation = Vector3(
        clamp(deformation.x, -0.1, 0.1),
        clamp(deformation.y, -0.2, 0.0),
        clamp(deformation.z, -0.1, 0.1)
    )

func update_raycast_direction():
    var direction_basis = Basis()
    direction_basis = direction_basis.rotated(Vector3.RIGHT, dynamic_caster)
    direction_basis = direction_basis.rotated(Vector3.UP, dynamic_toe)
    direction_basis = direction_basis.rotated(Vector3.FORWARD, dynamic_camber)
    raycast.cast_to = direction_basis * Vector3.DOWN * tire_radius * 1.5
    raycast.position = deformation

func update_effective_radius():
    var deflection = total_load / base_vertical_stiffness
    var max_deflection = tire_radius * 0.3
    var deflection_ratio = clamp(deflection / max_deflection, 0.0, 1.0)
    
    # Usar curva de rigidez vertical se disponível
    if vertical_stiffness_curve:
        deflection = total_load / (base_vertical_stiffness * vertical_stiffness_curve.interpolate(deflection_ratio))
    
    var base_radius = tire_radius - deflection
    
    # Aplicar curva de raio dinâmico
    if dynamic_radius_curve:
        var max_load = base_vertical_stiffness * max_deflection
        var load_ratio = clamp(total_load / max_load, 0.0, 1.0)
        base_radius *= dynamic_radius_curve.interpolate(load_ratio)
    
    effective_radius = clamp(base_radius, min_effective_radius, tire_radius * 1.2)

func update_relaxation_length():
    if relaxation_length_curve:
        relaxation_factor = relaxation_length_curve.interpolate(total_load)

func update_lateral_deformation():
    if lateral_deformation_curve:
        var max_load = base_vertical_stiffness * (tire_radius * 0.3)
        var load_ratio = clamp(total_load / max_load, 0.0, 1.0)
        lateral_deformation = lateral_deformation_curve.interpolate(load_ratio)

# Funções de acesso
func get_effective_radius() -> float:
    return effective_radius

func get_dynamic_camber() -> float:
    return dynamic_camber

func get_dynamic_toe() -> float: