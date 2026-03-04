#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TransientLimits {
    pub slew_per_second: f32,
    pub max_energy_delta_per_tick: f32,
}

impl Default for TransientLimits {
    fn default() -> Self {
        Self {
            slew_per_second: 50000.0,
            max_energy_delta_per_tick: 8000.0,
        }
    }
}

pub fn apply_slew(previous: f32, target: f32, dt: f32, limits: TransientLimits) -> f32 {
    let max_delta = (limits.slew_per_second * dt.max(0.0)).max(0.0);
    let delta = (target - previous).clamp(-max_delta, max_delta);
    previous + delta
}

pub fn clamp_energy_tick(
    force: [f32; 3],
    velocity: [f32; 3],
    dt: f32,
    max_energy_delta: f32,
) -> [f32; 3] {
    if dt <= 0.0 {
        return force;
    }
    let dot = force[0] * velocity[0] + force[1] * velocity[1] + force[2] * velocity[2];
    let delta_e = (dot * dt).abs();
    if delta_e <= max_energy_delta {
        return force;
    }
    let scale = max_energy_delta / delta_e.max(1.0e-6);
    [force[0] * scale, force[1] * scale, force[2] * scale]
}
