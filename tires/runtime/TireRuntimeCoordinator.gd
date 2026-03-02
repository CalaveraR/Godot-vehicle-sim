class_name TireRuntimeCoordinator
extends Node3D

# Single Authority Rule: este é o único entrypoint autorizado
# para executar o pipeline de pneu e aplicar forças no body.

@export var tire_width: float = 0.305
@export var tire_diameter: float = 0.720
@export var rim_diameter: float = 0.4572
@export var max_suspension_travel: float = 0.25
@export var raycast_count: int = 7
@export var vertical_zones: int = 7
@export var radial_zones: int = 8
@export var stiffness: float = 50000.0
@export var stiffness_curve: Curve

var tire_system: TireSystem
var wheel: Wheel
var suspension_system: SuspensionSystem
var wheel_dynamics: WheelDynamics

@onready var raycast_root: Node3D = $Raycasts
@onready var clipping_area: Area3D = $Area3D
@onready var curve_2d: Curve2D = preload("res://default_tire_profile.tres") as Curve2D

var _profile_mesh_builder: TireProfileMeshBuilder = TireProfileMeshBuilder.new()
var _contact_aggregation: TireContactAggregation = TireContactAggregation.new()
var _surface_response: TireSurfaceResponseModel = TireSurfaceResponseModel.new()
var _contact_runtime: TireContactRuntime = TireContactRuntime.new()
var _suspension_bridge: TireSuspensionBridge = TireSuspensionBridge.new()

var max_penetration_depth: float = 0.05
var contact_points: Array = []
var contact_normals: Array = []
var contact_forces: Array = []
var contact_grips: Array = []
var zone_grip_factors: Dictionary = {}
@export var auto_step_runtime: bool = false
@export var fixed_tick_hz: float = 120.0

var _time_accumulator: float = 0.0

func _ready() -> void:
	tire_system = get_parent().get_node_or_null("TireSystem")
	wheel = get_parent() as Wheel
	suspension_system = get_parent().get_node_or_null("SuspensionSystem")
	wheel_dynamics = get_parent().get_node_or_null("WheelDynamics")

	_generate_raycast_array()
	_generate_clipping_mesh()
	_initialize_grip_zones()

func _initialize_grip_zones() -> void:
	for i in radial_zones:
		zone_grip_factors[i] = 1.0

func _generate_raycast_array() -> void:
	if raycast_root:
		for child in raycast_root.get_children():
			child.queue_free()
	else:
		raycast_root = Node3D.new()
		raycast_root.name = "Raycasts"
		add_child(raycast_root)

	var spacing = tire_width / float(max(raycast_count - 1, 1))
	var start_x = -tire_width / 2.0

	for i in raycast_count:
		var ray = RayCast3D.new()
		ray.name = "Raycast_%d" % i
		ray.cast_to = Vector3(0, -(max_suspension_travel + tire_diameter / 2.0), 0)
		ray.enabled = true
		ray.translation = Vector3(start_x + i * spacing, 0, 0)
		ray.rotation_degrees.x = -90.0
		ray.collision_mask = 1
		raycast_root.add_child(ray)

func _generate_clipping_mesh() -> void:
	if not clipping_area:
		clipping_area = Area3D.new()
		clipping_area.name = "Area3D"
		add_child(clipping_area)

	var old = clipping_area.get_node_or_null("ClippingMesh")
	if old:
		old.queue_free()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "ClippingMesh"
	clipping_area.add_child(mesh_instance)
	mesh_instance.mesh = _profile_mesh_builder.build_profile_mesh(
		curve_2d,
		tire_width,
		tire_diameter,
		rim_diameter,
		vertical_zones,
		radial_zones
	)
	clipping_area.translation.y = -max_suspension_travel / 2.0

func update_contact_data() -> void:
	_contact_runtime.update_contact_data(
		raycast_root,
		global_transform.origin,
		tire_width,
		max_penetration_depth,
		stiffness,
		Callable(self, "calculate_local_grip"),
		contact_points,
		contact_normals,
		contact_forces,
		contact_grips
	)

func calculate_local_grip(lateral_pos: float, position: Vector3) -> float:
	return _surface_response.calculate_local_grip(
		tire_system,
		lateral_pos,
		position,
		radial_zones,
		zone_grip_factors
	)

func calculate_unified_data() -> ContactPatchData:
	return _contact_aggregation.build_unified_contact_data(
		contact_points,
		contact_normals,
		contact_forces,
		contact_grips,
		global_transform.origin,
		stiffness
	)

func apply_to_suspension(data: ContactPatchData) -> void:
	_suspension_bridge.apply_to_suspension(
		suspension_system,
		data,
		tire_diameter,
		tire_width,
		rim_diameter
	)

func apply_to_wheel(data: ContactPatchData) -> void:
	_contact_runtime.apply_to_wheel(wheel, data)

func apply_to_tire_system(data: ContactPatchData, step_dt: float) -> void:
	_contact_runtime.apply_to_tire_system(tire_system, data, Callable(self, "update_wear_and_temperature").bind(step_dt))

func update_wear_and_temperature(data: ContactPatchData, step_dt: float) -> void:
	_surface_response.update_wear_and_temperature(tire_system, wheel_dynamics, data, step_dt)
	update_aquaplaning_effects()
	update_zone_grip_from_tire_wear()

func update_aquaplaning_effects() -> void:
	if not tire_system:
		return
	_surface_response.update_aquaplaning_effects(tire_system, radial_zones, zone_grip_factors)

func update_zone_grip_from_tire_wear() -> void:
	if not tire_system:
		return
	_surface_response.update_zone_grip_from_tire_wear(tire_system, zone_grip_factors)

func apply_clipping_forces(body: RigidBody3D) -> void:
	if not body:
		return
	_surface_response.apply_clipping_forces(
		body,
		global_transform.origin,
		global_transform.basis,
		clipping_area,
		max_penetration_depth,
		stiffness,
		stiffness_curve,
		radial_zones,
		zone_grip_factors
	)

func get_clipping_ratio(body: Node3D) -> float:
	return _surface_response.get_clipping_ratio(body, clipping_area, max_penetration_depth)

func _stage_read_samples() -> void:
	update_contact_data()

func _stage_aggregate_patch() -> ContactPatchData:
	return calculate_unified_data()

func _stage_apply_forces(unified_data: ContactPatchData, step_dt: float) -> void:
	# Ordem determinística: surface response -> suspension bridge -> output forces
	apply_to_tire_system(unified_data, step_dt)
	apply_to_suspension(unified_data)
	apply_to_wheel(unified_data)
	_contact_runtime.apply_clipping_overlaps(clipping_area, Callable(self, "apply_clipping_forces"))

func _should_step(delta: float) -> bool:
	var step_dt := 1.0 / maxf(fixed_tick_hz, 1.0)
	_time_accumulator += maxf(delta, 0.0)
	if _time_accumulator < step_dt:
		return false
	_time_accumulator -= step_dt
	return true

func step_runtime_pipeline(delta: float = 0.0, force: bool = false) -> ContactPatchData:
	if not force and not _should_step(delta):
		return ContactPatchData.new()

	# Ordem determinística: leitura -> agregação -> aplicação no corpo
	_stage_read_samples()
	var step_dt := 1.0 / maxf(fixed_tick_hz, 1.0)
	var unified_data := _stage_aggregate_patch()
	_stage_apply_forces(unified_data, step_dt)
	return unified_data

func _physics_process(delta: float) -> void:
	if auto_step_runtime:
		step_runtime_pipeline(delta)
