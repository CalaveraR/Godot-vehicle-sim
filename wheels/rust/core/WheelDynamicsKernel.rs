use std::f32::consts::TAU;

use super::WheelDynamicsContracts::{WheelDynamicsInput, WheelDynamicsState};

/// Pure numeric kernel mirror for `wheels/godot/WheelDynamics.gd`.
/// Scene graph reads/writes and system orchestration must stay in GDScript.
pub fn step_wheel_dynamics(mut state: WheelDynamicsState, input: WheelDynamicsInput) -> WheelDynamicsState {
    let vx = input.velocity_local_z;
    let vy = input.velocity_local_x;

    let brake_direction = if state.angular_velocity != 0.0 {
        -state.angular_velocity.signum()
    } else {
        -1.0
    };

    let mut net_torque = input.engine_torque
        + input.brake_torque * brake_direction
        - (input.rolling_resistance * input.total_load);

    let aero_drag = (input.car_speed.max(0.0) / 50.0).clamp(0.0, 1.0) * 10.0;
    net_torque -= aero_drag * state.angular_velocity.signum();

    let safe_inertia = input.wheel_inertia.max(1.0e-6);
    state.angular_acceleration = net_torque / safe_inertia;
    state.angular_velocity += state.angular_acceleration * input.dt.max(0.0);

    state.flat_spot_angle = (state.flat_spot_angle + state.angular_velocity * input.dt.max(0.0)).rem_euclid(TAU);

    if input.total_load <= 0.0 {
        state.slip_ratio = 0.0;
        state.slip_angle = 0.0;
        return state;
    }

    let instant_slip_angle = if vx.abs() > 0.1 { vy.atan2(vx.abs()) } else { 0.0 };
    let relaxation_time = 0.3 * input.relaxation_factor.max(0.0) / vx.abs().max(0.1);
    let alpha = (input.dt.max(0.0) / relaxation_time.max(1.0e-3)).clamp(0.0, 1.0);
    state.transient_slip_angle += (instant_slip_angle - state.transient_slip_angle) * alpha;
    state.slip_angle = state.transient_slip_angle;

    let theoretical_speed = state.angular_velocity * input.wheel_radius.max(0.0);
    let instant_slip_ratio = if vx.abs() > 0.1 {
        (theoretical_speed - vx) / vx.abs()
    } else {
        theoretical_speed * 10.0
    };
    state.transient_slip_ratio += (instant_slip_ratio - state.transient_slip_ratio) * alpha;
    state.slip_ratio = state.transient_slip_ratio;

    state
}
