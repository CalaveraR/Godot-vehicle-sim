class_name WheelAssemblySystem
extends Node

enum SpecificationMode {NORMAL, SPECIAL}

export(SpecificationMode) var spec_mode = SpecificationMode.NORMAL
export var normal_width := 195.0
export var normal_aspect_ratio := 60.0
export var normal_rim_diameter := 15.0
export var special_width := 305.0
export var special_diameter := 720.0
export var special_rim_diameter := 18.0

var overall_diameter := 0.0
var static_radius := 0.0
var rolling_radius := 0.0
var contact_area := 0.0
var aspect_ratio := 0.0
var tire_width := 0.0
var rim_diameter := 0.0
var moment_of_inertia := 0.0
var unsprung_mass := 0.0
var original_pressure := 220.0
var original_brake_torque := 1500.0

onready var suspension: SuspensionSystem = $SuspensionSystem
onready var tire: TireSystem = $TireSystem
onready var dynamics: WheelDynamics = $WheelDynamics
onready var brake: BrakeSystem = $BrakeSystem
onready var hybrid_tire: HybridTireSystem = $HybridTireSystem

func _ready():
    calculate_properties()
    apply_to_systems()

func calculate_properties():
    match spec_mode:
        SpecificationMode.NORMAL:
            tire_width = normal_width / 1000.0
            rim_diameter = normal_rim_diameter * 0.0254
            aspect_ratio = normal_aspect_ratio / 100.0
            var sidewall_height = tire_width * aspect_ratio
            overall_diameter = rim_diameter + (2 * sidewall_height)
            static_radius = overall_diameter / 2.0
            contact_area = tire_width * (sidewall_height * 0.7)
            
        SpecificationMode.SPECIAL:
            tire_width = special_width / 1000.0
            rim_diameter = special_rim_diameter * 0.0254
            overall_diameter = special_diameter / 1000.0
            static_radius = overall_diameter / 2.0
            var sidewall_height = (overall_diameter - rim_diameter) / 2.0
            aspect_ratio = sidewall_height / tire_width
            contact_area = tire_width * (sidewall_height * 0.8)
    
    rolling_radius = static_radius * 0.96
    unsprung_mass = calculate_unsprung_mass()
    moment_of_inertia = calculate_moment_of_inertia()
    original_pressure = tire.tire_pressure if tire else 220.0
    original_brake_torque = brake.max_brake_torque if brake else 1500.0

func calculate_unsprung_mass() -> float:
    var volume = PI * pow(static_radius, 2) * tire_width
    var density = 1200.0
    return volume * density * 0.7

func calculate_moment_of_inertia() -> float:
    return 0.5 * unsprung_mass * pow(static_radius, 2)

func apply_to_systems():
    if suspension:
        suspension.tire_radius = static_radius
        suspension.tire_width = tire_width
        suspension.min_effective_radius = static_radius * 0.6
        suspension.unsprung_mass = unsprung_mass
        suspension.reset_raycast()
        
        match suspension.get_suspension_type_name():
            "Double Wishbone":
                suspension.motion_ratio = 0.85
            "Solid Axle":
                var axle_path = get_parent().get_path()
                suspension.connected_wheel = axle_path.get_node("OtherWheel")
            "Air Suspension":
                suspension.air_pressure = 600.0
    
    if tire:
        tire.tire_radius = static_radius
        tire.tire_width = tire_width
        tire.contact_area = contact_area
        tire.base_carcass_stiffness = 10000.0 * (tire_width / 0.2)
        tire.original_pressure = original_pressure
    
    if hybrid_tire:
        hybrid_tire.tire_width = tire_width
        hybrid_tire.tire_diameter = overall_diameter
        hybrid_tire.rim_diameter = rim_diameter
    
    if dynamics:
        dynamics.wheel_mass = unsprung_mass
        dynamics.calculate_wheel_inertia(rolling_radius)
    
    if brake:
        brake.max_brake_torque = original_brake_torque * (rim_diameter / 0.381)
        brake.original_brake_torque = brake.max_brake_torque

func update_rolling_radius(new_radius: float):
    rolling_radius = new_radius
    if dynamics:
        dynamics.calculate_wheel_inertia(new_radius)

func set_normal_spec(width: float, aspect_ratio: float, rim_diameter_inch: float):
    spec_mode = SpecificationMode.NORMAL
    normal_width = width
    normal_aspect_ratio = aspect_ratio
    normal_rim_diameter = rim_diameter_inch
    calculate_properties()
    apply_to_systems()

func set_special_spec(width: float, diameter_mm: float, rim_diameter_inch: float):
    spec_mode = SpecificationMode.SPECIAL
    special_width = width
    special_diameter = diameter_mm
    special_rim_diameter = rim_diameter_inch
    calculate_properties()
    apply_to_systems()

func get_spec_string() -> String:
    match spec_mode:
        SpecificationMode.NORMAL:
            return "%.0f/%.0fR%.0f" % [normal_width, normal_aspect_ratio, normal_rim_diameter]
        SpecificationMode.SPECIAL:
            return "%.0f/%.0fR%.0f" % [special_width, special_diameter, special_rim_diameter]

func get_properties() -> Dictionary:
    return {
        "diameter": overall_diameter,
        "static_radius": static_radius,
        "rolling_radius": rolling_radius,
        "width": tire_width,
        "aspect_ratio": aspect_ratio,
        "contact_area": contact_area,
        "unsprung_mass": unsprung_mass,
        "moment_of_inertia": moment_of_inertia
    }