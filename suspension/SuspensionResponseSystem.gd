class_name SuspensionResponseSystem
extends Node

export(Curve) var load_transfer_response_curve
export(Curve) var bump_steer_response_curve
export(Curve) var roll_center_movement_curve

var load_transfer = 0.0
var dynamic_bump_steer = 0.0
var roll_center_height = 0.3

func calculate_dynamic_response(car_body: RigidBody, suspension_load: float, lateral_g: float):
    if load_transfer_response_curve:
        load_transfer = load_transfer_response_curve.interpolate_baked(abs(lateral_g)) * sign(lateral_g)
    
    if bump_steer_response_curve:
        dynamic_bump_steer = bump_steer_response_curve.interpolate_baked(suspension_load / 10000.0)
    
    if roll_center_movement_curve:
        roll_center_height = roll_center_movement_curve.interpolate_baked(suspension_load / 10000.0)

func apply_response(suspension: SuspensionSystem):
    suspension.total_load += load_transfer * 1000
    
    match suspension.suspension_type:
        SuspensionSystem.SUSPENSION_TYPE.MACPHERSON:
            suspension.dynamic_toe += dynamic_bump_steer * 0.8
        SuspensionSystem.SUSPENSION_TYPE.DOUBLE_WISHBONE:
            suspension.dynamic_toe += dynamic_bump_steer * 1.2
        SuspensionSystem.SUSPENSION_TYPE.SOLID_AXLE:
            suspension.dynamic_toe += dynamic_bump_steer * 0.5
        _:
            suspension.dynamic_toe += dynamic_bump_steer
    
    suspension.deformation.y = (suspension.tire_radius - roll_center_height) * 0.5