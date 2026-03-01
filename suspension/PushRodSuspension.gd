class_name PushRodSuspension
extends SuspensionSystem

export var rocker_ratio = 1.5
export var pushrod_angle = 0.3

func _ready():
    suspension_type = SUSPENSION_TYPE.PUSH_ROD

func calculate_specific_geometry(total_load: float):
    var spring_force = total_load * rocker_ratio
    deformation.y = spring_force / base_vertical_stiffness
    pushrod_angle = 0.3 + deformation.y * 0.1

func calculate_anti_features():
    anti_dive = 0.4
    anti_squat = 0.35

func get_suspension_type_name() -> String:
    return "Push Rod"