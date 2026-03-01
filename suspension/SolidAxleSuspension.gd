class_name SolidAxleSuspension
extends SuspensionSystem

export var axle_stiffness = 1000000.0

func _ready():
    suspension_type = SUSPENSION_TYPE.SOLID_AXLE

func calculate_specific_geometry(total_load: float):
    var other_wheel = get_node_or_null(connected_wheel)
    if other_wheel and other_wheel.has_method("get_total_load"):
        var avg_load = (total_load + other_wheel.get_total_load()) / 2.0
        var load_difference = total_load - avg_load
        deformation.y = load_difference / axle_stiffness

func calculate_roll_center() -> Vector3:
    return Vector3(0, tire_radius * 0.3, 0)

func get_suspension_type_name() -> String:
    return "Solid Axle"