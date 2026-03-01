class_name MultiLinkSuspension
extends SuspensionSystem

export var link_count = 5
export var link_stiffness = 10000.0
var link_forces = []

func _ready():
    suspension_type = SUSPENSION_TYPE.MULTILINK
    link_forces.resize(link_count)
    for i in link_count:
        link_forces[i] = 0.0

func calculate_specific_geometry(total_load: float):
    var load_per_link = total_load / link_count
    for i in link_count:
        link_forces[i] = load_per_link * (1.0 + sin(i * 0.5))
    
    dynamic_camber = link_forces[0] * 0.00001
    dynamic_toe = (link_forces[1] - link_forces[2]) * 0.00002

func calculate_anti_features():
    anti_dive = 0.3
    anti_squat = 0.25

func get_suspension_type_name() -> String:
    return "MultiLink"