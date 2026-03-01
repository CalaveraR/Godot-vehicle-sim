class_name FlatSpotSystem
extends Node

export var max_flat_spot_depth = 0.02
export var flat_spot_recovery_rate = 0.0001
export var flat_spot_sensitivity = 0.8
export var flat_spot_vibration_freq = 15.0
export var vibration_transmission = 0.5
export(Curve) var acoustic_profile_curve
export(Curve) var flat_spot_torque_curve
export(Curve) var vibration_angular_distribution_curve

enum FLAT_SPOT_MODE {DISABLED, VIRTUAL_RECOVERY, HYBRID_RECOVERY, PHYSICAL_ONLY}
export(FLAT_SPOT_MODE) var flat_spot_mode = FLAT_SPOT_MODE.HYBRID_RECOVERY

export(Curve) var virtual_recovery_curve
export(Curve) var hybrid_recovery_curve
export(Curve) var mechanical_wear_curve
export(Curve) var flat_spot_formation_curve
export(Curve) var flat_spot_vibration_curve

var flat_spot_depth = 0.0
var flat_spot_angle = 0.0
var chassis_vibration = 0.0

func update(delta: float, wheel_angular_velocity: float, is_dragging: bool, 
          surface_temperature: float, current_load: float):
    
    if is_dragging && abs(wheel_angular_velocity) < 0.1:
        var formation_rate = flat_spot_sensitivity * delta
        if flat_spot_formation_curve:
            formation_rate *= flat_spot_formation_curve.interpolate_baked(surface_temperature)
        
        formation_rate *= 1.0 + (current_load / 10000.0)
        
        flat_spot_depth = min(max_flat_spot_depth, flat_spot_depth + formation_rate)
    
    elif flat_spot_depth > 0:
        var recovery_rate = flat_spot_recovery_rate
        match flat_spot_mode:
            FLAT_SPOT_MODE.VIRTUAL_RECOVERY:
                if virtual_recovery_curve:
                    recovery_rate *= virtual_recovery_curve.interpolate_baked(flat_spot_depth)
            FLAT_SPOT_MODE.HYBRID_RECOVERY:
                if hybrid_recovery_curve:
                    recovery_rate *= hybrid_recovery_curve.interpolate_baked(flat_spot_depth)
            FLAT_SPOT_MODE.PHYSICAL_ONLY:
                if mechanical_wear_curve:
                    recovery_rate *= mechanical_wear_curve.interpolate_baked(flat_spot_depth)
        
        flat_spot_depth = max(0, flat_spot_depth - recovery_rate * delta)
    
    update_vibration_effects(delta, wheel_angular_velocity, flat_spot_angle)

func update_vibration_effects(delta: float, wheel_angular_velocity: float, flat_spot_angle: float):
    var vibration_intensity = 0.0
    if flat_spot_depth > 0.01:
        var angle_factor = 1.0
        if vibration_angular_distribution_curve:
            var normalized_angle = fmod(flat_spot_angle, PI * 2) / (PI * 2)
            angle_factor = vibration_angular_distribution_curve.interpolate_baked(normalized_angle)
        
        vibration_intensity = flat_spot_depth * flat_spot_vibration_freq * wheel_angular_velocity * angle_factor
        if flat_spot_vibration_curve:
            vibration_intensity *= flat_spot_vibration_curve.interpolate_baked(wheel_angular_velocity)
    
    chassis_vibration = vibration_intensity * vibration_transmission

func get_torque_factor(angular_velocity: float, current_load: float) -> float:
    if flat_spot_depth > 0.001:
        var torque_factor = 1.0
        if flat_spot_torque_curve:
            var velocity_factor = clamp(abs(angular_velocity) / 10.0, 0.0, 1.0)
            var load_factor = clamp(current_load / 10000.0, 0.0, 1.0)
            var combined_factor = (velocity_factor + load_factor) / 2.0
            torque_factor = flat_spot_torque_curve.interpolate_baked(combined_factor)
        return torque_factor
    return 1.0

func get_vibration() -> float:
    return chassis_vibration

func get_flat_spot_depth() -> float:
    return flat_spot_depth

func get_sound_intensity() -> float:
    if acoustic_profile_curve:
        return acoustic_profile_curve.interpolate_baked(chassis_vibration)
    return chassis_vibration