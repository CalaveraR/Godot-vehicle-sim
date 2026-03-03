use serde::{Deserialize, Serialize};

/// Flat input contract expected by the wheel numeric kernel.
/// Engine-dependent gather/apply remains in `wheels/godot/Wheel.gd`.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct WheelDynamicsInput {
    pub dt: f32,
    pub engine_torque: f32,
    pub brake_torque: f32,
    pub total_load: f32,
    pub relaxation_factor: f32,
    pub wheel_inertia: f32,
    pub wheel_radius: f32,
    pub rolling_resistance: f32,
    pub velocity_local_x: f32,
    pub velocity_local_z: f32,
    pub car_speed: f32,
}

/// Stateful wheel integration memory (pure numeric state).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct WheelDynamicsState {
    pub angular_velocity: f32,
    pub angular_acceleration: f32,
    pub slip_ratio: f32,
    pub slip_angle: f32,
    pub transient_slip_ratio: f32,
    pub transient_slip_angle: f32,
    pub flat_spot_angle: f32,
}

impl Default for WheelDynamicsState {
    fn default() -> Self {
        Self {
            angular_velocity: 0.0,
            angular_acceleration: 0.0,
            slip_ratio: 0.0,
            slip_angle: 0.0,
            transient_slip_ratio: 0.0,
            transient_slip_angle: 0.0,
            flat_spot_angle: 0.0,
        }
    }
}
