#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

use crate::{
    aggregate_patch_with_conventions, compute_effective_radius_with_conventions, PatchSample,
    TireCoreConventions,
};

#[derive(Debug, Clone, Copy, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct WheelState {
    pub omega: f32,
    pub steer_angle: f32,
    pub throttle: f32,
    pub brake: f32,
    pub velocity_local_x: f32,
    pub velocity_local_z: f32,
    pub tire_radius: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct ContactSampleRaw {
    pub penetration: f32,
    pub confidence: f32,
    pub slip_x: f32,
    pub slip_y: f32,
    pub position_local: [f32; 3],
    pub normal_local: [f32; 3],
}

#[derive(Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct CoreInput {
    pub wheel: WheelState,
    pub samples: Vec<ContactSampleRaw>,
    pub conventions: TireCoreConventions,
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct DebugScalars {
    pub effective_radius: f32,
    pub contact_area_est: f32,
    pub slip_avg: [f32; 2],
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct CoreOutput {
    pub fx: f32,
    pub fy: f32,
    pub fz: f32,
    pub mz: f32,
    pub center_of_pressure_local: [f32; 3],
    pub confidence: f32,
    pub debug: DebugScalars,
}

pub fn solve_core(input: &CoreInput) -> CoreOutput {
    if input.samples.is_empty() {
        return CoreOutput::default();
    }

    let mapped: Vec<PatchSample> = input
        .samples
        .iter()
        .map(|s| PatchSample {
            weight: s.penetration.max(0.0) * s.confidence.clamp(0.0, 1.0),
            penetration: s.penetration,
            slip_x: s.slip_x,
            slip_y: s.slip_y,
        })
        .collect();

    let patch = aggregate_patch_with_conventions(&mapped, input.conventions);

    let mut weighted_pos = [0.0_f32; 3];
    let mut weight_sum = 0.0_f32;
    for s in &input.samples {
        let w = s.penetration.max(0.0) * s.confidence.clamp(0.0, 1.0);
        weight_sum += w;
        weighted_pos[0] += s.position_local[0] * w;
        weighted_pos[1] += s.position_local[1] * w;
        weighted_pos[2] += s.position_local[2] * w;
    }

    let cop = if weight_sum > input.conventions.epsilon {
        [
            weighted_pos[0] / weight_sum,
            weighted_pos[1] / weight_sum,
            weighted_pos[2] / weight_sum,
        ]
    } else {
        [0.0, 0.0, 0.0]
    };

    let fz = (patch.penetration_avg * 120000.0).max(0.0);
    let fx = -patch.slip_x_avg * fz * 0.5;
    let fy = -patch.slip_y_avg * fz * 0.7;

    CoreOutput {
        fx,
        fy,
        fz,
        mz: fy * cop[0],
        center_of_pressure_local: cop,
        confidence: patch.contact_confidence,
        debug: DebugScalars {
            effective_radius: compute_effective_radius_with_conventions(
                input.wheel.tire_radius,
                input.wheel.tire_radius * 0.7,
                fz,
                120000.0,
                input.conventions,
            ),
            contact_area_est: weight_sum,
            slip_avg: [patch.slip_x_avg, patch.slip_y_avg],
        },
    }
}
