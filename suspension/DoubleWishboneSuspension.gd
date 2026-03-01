class_name DoubleWishboneSuspension
extends SuspensionSystem

export var upper_wishbone_length = 0.3
export var lower_wishbone_length = 0.4
export var wishbone_angle = 0.1

func _ready():
    suspension_type = SUSPENSION_TYPE.DOUBLE_WISHBONE

func calculate_specific_geometry(total_load: float):
    dynamic_camber = wishbone_angle + total_load * 0.00005
    dynamic_toe = total_load * 0.00001

func calculate_roll_center() -> Vector3:
    var height = tire_radius - (upper_wishbone_length + lower_wishbone_length) * 0.5
    return Vector3(0, height, 0)

func calculate_instant_center() -> Vector3:
    return Vector3(0, tire_radius * 0.6, -tire_radius * 0.8)

func get_suspension_type_name() -> String:
    return "Double Wishbone"