class_name PullRodSuspension
extends SuspensionSystem

export var rocker_ratio = 1.7
export var pullrod_angle = -0.2

func _ready():
    suspension_type = SUSPENSION_TYPE.PULL_ROD

func calculate_specific_geometry(total_load: float):
    var spring_force = total_load * rocker_ratio
    deformation.y = spring_force / base_vertical_stiffness
    pullrod_angle = -0.2 - deformation.y * 0.1

func get_suspension_type_name() -> String:
    return "Pull Rod"