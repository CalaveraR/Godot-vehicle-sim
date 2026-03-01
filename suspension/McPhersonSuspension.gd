class_name McPhersonSuspension
extends SuspensionSystem

export var upper_mount_offset = 0.2
export var spring_resting_length = 0.4
export var anti_roll_stiffness = 15000.0
export(Curve) var bump_steer_curve
export(Curve) var camber_compression_curve

func _ready():
    suspension_type = SUSPENSION_TYPE.MACPHERSON

func calculate_specific_geometry(total_load: float):
    if bump_steer_curve:
        dynamic_toe += bump_steer_curve.interpolate_baked(deformation.y)
    
    if camber_compression_curve:
        dynamic_camber += camber_compression_curve.interpolate_baked(deformation.y)

func calculate_roll_center() -> Vector3:
    var height = tire_radius - deformation.y * 0.7
    return Vector3(0, height, 0)

func calculate_instant_center() -> Vector3:
    return Vector3(0, tire_radius * 0.5, -tire_radius)

func calculate_anti_features():
    anti_dive = 0.2
    anti_squat = 0.1

func get_suspension_type_name() -> String:
    return "McPherson"