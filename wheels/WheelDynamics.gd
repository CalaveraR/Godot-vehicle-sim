class_name WheelDynamics
extends Node

export var wheel_mass = 20.0
export var gyroscopic_factor = 0.1
export var rolling_resistance = 0.015
export(Curve) var aerodynamic_drag_curve
export(Curve) var rolling_resistance_curve

var wheel_angular_velocity = 0.0
var wheel_angular_acceleration = 0.0
var wheel_slip_ratio = 0.0
var wheel_slip_angle = 0.0
var transient_slip_ratio = 0.0
var transient_slip_angle = 0.0
var wheel_inertia = 1.2
var is_dragging = false
var flat_spot_angle = 0.0

func calculate_wheel_inertia(tire_radius: float):
    wheel_inertia = 0.5 * wheel_mass * (tire_radius * tire_radius) * 1.3

func update(delta: float, engine_torque: float, brake_torque: float, 
           total_load: float, relaxation_factor: float, car_body: RigidBody,
           contact_data: Dictionary, global_transform: Transform):
    
    var vx = 0.0
    if contact_data:
        var offset = (global_transform.origin - car_body.global_transform.origin)
        var point_velocity = car_body.linear_velocity + car_body.angular_velocity.cross(offset)
        var local_velocity = global_transform.basis.xform_inv(point_velocity)
        vx = local_velocity.z
    
    var rr = rolling_resistance
    if rolling_resistance_curve:
        rr = rolling_resistance_curve.interpolate_baked(clamp(abs(vx), 0.0, 30.0))
    
    var brake_direction = -sign(wheel_angular_velocity) if wheel_angular_velocity != 0 else -1
    var net_torque = engine_torque + brake_torque * brake_direction - (rr * total_load)
    
    var aero_drag = 0.0
    if aerodynamic_drag_curve && car_body:
        var speed = car_body.linear_velocity.length()
        aero_drag = aerodynamic_drag_curve.interpolate_baked(speed / 50.0) * 10.0
    net_torque -= aero_drag * sign(wheel_angular_velocity)
    
    wheel_angular_acceleration = net_torque / wheel_inertia
    wheel_angular_velocity += wheel_angular_acceleration * delta
    
    flat_spot_angle = fmod(flat_spot_angle + wheel_angular_velocity * delta, PI * 2)
    
    calculate_slip(delta, car_body, contact_data, global_transform, relaxation_factor, vx)

func calculate_slip(delta: float, car_body: RigidBody, contact_data: Dictionary, 
                  global_transform: Transform, relaxation_factor: float, vx: float):
    if not contact_data:
        wheel_slip_ratio = 0.0
        wheel_slip_angle = 0.0
        return
    
    var vy = 0.0
    var offset = (global_transform.origin - car_body.global_transform.origin)
    var point_velocity = car_body.linear_velocity + car_body.angular_velocity.cross(offset)
    var local_velocity = global_transform.basis.xform_inv(point_velocity)
    vy = local_velocity.x
    
    var instant_slip_angle = 0.0
    if abs(vx) > 0.1:
        instant_slip_angle = atan2(vy, abs(vx))
    
    var relaxation_time = 0.3 * relaxation_factor / max(0.1, abs(vx))
    transient_slip_angle = lerp(transient_slip_angle, instant_slip_angle, delta / max(0.001, relaxation_time))
    wheel_slip_angle = transient_slip_angle
    
    var theoretical_speed = wheel_angular_velocity * get_effective_radius()
    var instant_slip_ratio = 0.0
    if abs(vx) > 0.1:
        instant_slip_ratio = (theoretical_speed - vx) / abs(vx)
    else:
        instant_slip_ratio = theoretical_speed * 10.0
    
    transient_slip_ratio = lerp(transient_slip_ratio, instant_slip_ratio, delta / max(0.001, relaxation_time))
    wheel_slip_ratio = transient_slip_ratio

func set_dragging(dragging: bool):
    is_dragging = dragging

func get_wheel_slip() -> Vector2:
    return Vector2(wheel_slip_ratio, wheel_slip_angle)

func get_angular_velocity() -> float:
    return wheel_angular_velocity

func get_flat_spot_angle() -> float:
    return flat_spot_angle

func get_effective_radius() -> float:
    return 0.3  # Valor padrão, será substituído pela suspensão