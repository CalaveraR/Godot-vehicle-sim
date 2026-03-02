#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct PatchSample {
    pub weight: f32,
    pub penetration: f32,
    pub slip_x: f32,
    pub slip_y: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct PatchAggregate {
    pub contact_confidence: f32,
    pub penetration_avg: f32,
    pub penetration_max: f32,
    pub slip_x_avg: f32,
    pub slip_y_avg: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TireCoreConventions {
    pub epsilon: f32,
    pub min_stiffness: f32,
    pub min_positive_weight: f32,
    pub contact_penetration_threshold: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct WheelStateMirror {
    pub linear_velocity_ws: [f32; 3],
    pub angular_velocity_ws: [f32; 3],
    pub tire_radius: f32,
    pub tire_width: f32,
    pub camber: f32,
    pub toe: f32,
    pub steer_input: f32,
    pub throttle_input: f32,
    pub brake_input: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TireForcesMirror {
    pub fx: f32,
    pub fy: f32,
    pub fz: f32,
    pub mz: f32,
    pub center_of_pressure_ws: [f32; 3],
    pub contact_confidence: f32,
}

impl Default for TireCoreConventions {
    fn default() -> Self {
        Self {
            epsilon: 1.0e-6,
            min_stiffness: 1.0e-4,
            min_positive_weight: 0.0,
            contact_penetration_threshold: 0.0,
        }
    }
}

impl Default for WheelStateMirror {
    fn default() -> Self {
        Self {
            linear_velocity_ws: [0.0, 0.0, 0.0],
            angular_velocity_ws: [0.0, 0.0, 0.0],
            tire_radius: 0.0,
            tire_width: 0.0,
            camber: 0.0,
            toe: 0.0,
            steer_input: 0.0,
            throttle_input: 0.0,
            brake_input: 0.0,
        }
    }
}

impl Default for TireForcesMirror {
    fn default() -> Self {
        Self {
            fx: 0.0,
            fy: 0.0,
            fz: 0.0,
            mz: 0.0,
            center_of_pressure_ws: [0.0, 0.0, 0.0],
            contact_confidence: 0.0,
        }
    }
}

#[cfg(feature = "serde")]
pub fn serialize_wheel_state(state: &WheelStateMirror) -> Result<String, serde_json::Error> {
    serde_json::to_string(state)
}

#[cfg(feature = "serde")]
pub fn serialize_tire_forces(forces: &TireForcesMirror) -> Result<String, serde_json::Error> {
    serde_json::to_string(forces)
}

#[cfg(feature = "serde")]
pub fn deserialize_wheel_state(payload: &str) -> Result<WheelStateMirror, serde_json::Error> {
    serde_json::from_str(payload)
}

#[cfg(feature = "serde")]
pub fn deserialize_tire_forces(payload: &str) -> Result<TireForcesMirror, serde_json::Error> {
    serde_json::from_str(payload)
}

#[cfg(feature = "validator")]
pub fn validate_wheel_state(state: &WheelStateMirror) -> bool {
    state.tire_radius >= 0.0
        && state.tire_width >= 0.0
        && state.steer_input.is_finite()
        && state.throttle_input.is_finite()
        && state.brake_input.is_finite()
}

pub fn normalize_weights(weights: &[f32]) -> Vec<f32> {
    normalize_weights_with_conventions(weights, TireCoreConventions::default())
}

pub fn normalize_weights_with_conventions(
    weights: &[f32],
    conventions: TireCoreConventions,
) -> Vec<f32> {
    let sum: f32 = weights
        .iter()
        .copied()
        .filter(|v| *v > conventions.min_positive_weight)
        .sum();

    if sum <= conventions.epsilon {
        return vec![0.0; weights.len()];
    }

    weights
        .iter()
        .map(|v| {
            if *v > conventions.min_positive_weight {
                *v / sum
            } else {
                0.0
            }
        })
        .collect()
}

pub fn aggregate_patch(samples: &[PatchSample]) -> PatchAggregate {
    aggregate_patch_with_conventions(samples, TireCoreConventions::default())
}

pub fn aggregate_patch_with_conventions(
    samples: &[PatchSample],
    conventions: TireCoreConventions,
) -> PatchAggregate {
    if samples.is_empty() {
        return PatchAggregate {
            contact_confidence: 0.0,
            penetration_avg: 0.0,
            penetration_max: 0.0,
            slip_x_avg: 0.0,
            slip_y_avg: 0.0,
        };
    }

    let raw_weights: Vec<f32> = samples.iter().map(|s| s.weight).collect();
    let weights = normalize_weights_with_conventions(&raw_weights, conventions);

    let mut penetration_avg: f32 = 0.0;
    let mut penetration_max: f32 = 0.0;
    let mut slip_x_avg: f32 = 0.0;
    let mut slip_y_avg: f32 = 0.0;
    let mut contact_confidence: f32 = 0.0;

    for (sample, w) in samples.iter().zip(weights.iter().copied()) {
        if sample.penetration > conventions.contact_penetration_threshold {
            contact_confidence += w;
        }
        penetration_avg += sample.penetration * w;
        penetration_max = penetration_max.max(sample.penetration);
        slip_x_avg += sample.slip_x * w;
        slip_y_avg += sample.slip_y * w;
    }

    PatchAggregate {
        contact_confidence: contact_confidence.clamp(0.0, 1.0),
        penetration_avg,
        penetration_max,
        slip_x_avg,
        slip_y_avg,
    }
}

pub fn compute_effective_radius(
    tire_radius: f32,
    min_effective_radius: f32,
    vertical_load: f32,
    stiffness: f32,
) -> f32 {
    compute_effective_radius_with_conventions(
        tire_radius,
        min_effective_radius,
        vertical_load,
        stiffness,
        TireCoreConventions::default(),
    )
}

pub fn compute_effective_radius_with_conventions(
    tire_radius: f32,
    min_effective_radius: f32,
    vertical_load: f32,
    stiffness: f32,
    conventions: TireCoreConventions,
) -> f32 {
    if tire_radius <= 0.0 {
        return 0.0;
    }
    let safe_stiffness = stiffness.max(conventions.min_stiffness);
    let compression = (vertical_load.max(0.0) / safe_stiffness).min(tire_radius);
    (tire_radius - compression)
        .max(min_effective_radius)
        .min(tire_radius)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_preserves_sum() {
        let out = normalize_weights(&[1.0, 1.0, 2.0]);
        let sum: f32 = out.iter().sum();
        assert!((sum - 1.0).abs() < 1.0e-6);
    }

    #[test]
    fn aggregate_returns_expected_confidence() {
        let patch = aggregate_patch(&[
            PatchSample {
                weight: 1.0,
                penetration: 0.02,
                slip_x: 0.1,
                slip_y: 0.0,
            },
            PatchSample {
                weight: 1.0,
                penetration: 0.00,
                slip_x: 0.2,
                slip_y: 0.1,
            },
        ]);
        assert!((patch.contact_confidence - 0.5).abs() < 1.0e-6);
        assert!(patch.penetration_max >= patch.penetration_avg);
    }

    #[test]
    fn effective_radius_is_bounded() {
        let r = compute_effective_radius(0.34, 0.27, 4200.0, 120000.0);
        assert!(r <= 0.34);
        assert!(r >= 0.27);
    }

    #[test]
    fn conventions_can_change_contact_threshold() {
        let patch = aggregate_patch_with_conventions(
            &[PatchSample {
                weight: 1.0,
                penetration: 0.02,
                slip_x: 0.0,
                slip_y: 0.0,
            }],
            TireCoreConventions {
                contact_penetration_threshold: 0.03,
                ..TireCoreConventions::default()
            },
        );
        assert_eq!(patch.contact_confidence, 0.0);
    }

    #[cfg(feature = "serde")]
    #[test]
    fn serde_roundtrip_wheel_state() {
        let s = WheelStateMirror {
            tire_radius: 0.34,
            throttle_input: 0.7,
            ..WheelStateMirror::default()
        };
        let payload = serialize_wheel_state(&s).unwrap();
        let restored = deserialize_wheel_state(&payload).unwrap();
        assert_eq!(restored.tire_radius, 0.34);
        assert_eq!(restored.throttle_input, 0.7);
    }
}
