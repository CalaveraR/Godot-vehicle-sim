//! [CORE_RS] tire_core
//! Deterministic Rust golden core for tire logic parity.
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


#[derive(Debug, Clone, Copy, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

impl Vec2 {
    pub fn length(self) -> f32 { (self.x * self.x + self.y * self.y).sqrt() }
    pub fn normalized(self) -> Self {
        let len = self.length();
        if len <= 1.0e-6 { Self::default() } else { Self { x: self.x / len, y: self.y / len } }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

impl Vec3 {
    pub fn dot(self, rhs: Self) -> f32 { self.x * rhs.x + self.y * rhs.y + self.z * rhs.z }
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TireSampleMirror {
    pub valid: bool,
    pub contact_pos_local: Vec3,
    pub contact_normal_local: Vec3,
    pub contact_pos_ws: Vec3,
    pub penetration: f32,
    pub confidence: f32,
    pub slip_vector: Vec2,
    pub penetration_velocity: f32,
}

impl Default for TireSampleMirror {
    fn default() -> Self {
        Self {
            valid: false,
            contact_pos_local: Vec3::default(),
            contact_normal_local: Vec3 { x: 0.0, y: 1.0, z: 0.0 },
            contact_pos_ws: Vec3::default(),
            penetration: 0.0,
            confidence: 0.0,
            slip_vector: Vec2::default(),
            penetration_velocity: 0.0,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct ContactPatchDataMirror {
    pub patch_confidence: f32,
    pub center_of_pressure_local: Vec3,
    pub penetration_avg: f32,
    pub penetration_max: f32,
    pub average_slip: Vec2,
    pub normalized_weights: Vec<f32>,
    pub total_weight: f32,
}

impl Default for ContactPatchDataMirror {
    fn default() -> Self {
        Self {
            patch_confidence: 0.0,
            center_of_pressure_local: Vec3::default(),
            penetration_avg: 0.0,
            penetration_max: 0.0,
            average_slip: Vec2::default(),
            normalized_weights: vec![],
            total_weight: 0.0,
        }
    }
}

impl ContactPatchDataMirror {
    pub fn from_samples(samples: &[TireSampleMirror]) -> Self {
        if samples.is_empty() { return Self::default(); }

        let mut weighted_pos_local = Vec3::default();
        let mut weighted_slip = Vec2::default();
        let mut conf_sum = 0.0;
        let mut penetration_sum = 0.0;
        let mut valid_count = 0.0;
        let mut raw_weights = vec![0.0; samples.len()];
        let mut total_weight = 0.0;
        let mut penetration_max: f32 = 0.0;

        for (i, sample) in samples.iter().enumerate() {
            if !sample.valid {
                continue;
            }
            let w = sample.penetration.max(0.0) * sample.confidence.clamp(0.0, 1.0);
            raw_weights[i] = w;
            if w <= 0.0 {
                continue;
            }
            weighted_pos_local.x += sample.contact_pos_local.x * w;
            weighted_pos_local.y += sample.contact_pos_local.y * w;
            weighted_pos_local.z += sample.contact_pos_local.z * w;

            weighted_slip.x += sample.slip_vector.x * w;
            weighted_slip.y += sample.slip_vector.y * w;

            penetration_sum += sample.penetration;
            penetration_max = penetration_max.max(sample.penetration);
            conf_sum += sample.confidence;
            total_weight += w;
            valid_count += 1.0;
        }

        let normalized_weights = normalize_weights(&raw_weights);
        if total_weight <= 0.0 || valid_count == 0.0 {
            return Self { normalized_weights, ..Self::default() };
        }

        Self {
            patch_confidence: (conf_sum / valid_count).clamp(0.0, 1.0),
            center_of_pressure_local: Vec3 {
                x: weighted_pos_local.x / total_weight,
                y: weighted_pos_local.y / total_weight,
                z: weighted_pos_local.z / total_weight,
            },
            penetration_avg: penetration_sum / valid_count,
            penetration_max,
            average_slip: Vec2 {
                x: weighted_slip.x / total_weight,
                y: weighted_slip.y / total_weight,
            },
            normalized_weights,
            total_weight,
        }
    }

    pub fn center_of_pressure_ws(&self, samples: &[TireSampleMirror]) -> Vec3 {
        if samples.is_empty() || self.normalized_weights.is_empty() { return Vec3::default(); }
        let mut acc = Vec3::default();
        for (s, w) in samples.iter().zip(self.normalized_weights.iter().copied()) {
            acc.x += s.contact_pos_ws.x * w;
            acc.y += s.contact_pos_ws.y * w;
            acc.z += s.contact_pos_ws.z * w;
        }
        acc
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TireCoreMirrorConfig {
    pub confidence_min_for_contact: f32,
    pub emergency_fz_falloff_rate: f32,
    pub energy_delta_limit: f32,
}

impl Default for TireCoreMirrorConfig {
    fn default() -> Self {
        Self {
            confidence_min_for_contact: 0.1,
            emergency_fz_falloff_rate: 10.0,
            energy_delta_limit: 8000.0,
        }
    }
}

pub fn step_wheel_mirror(
    shader_samples: &[TireSampleMirror],
    raycast_samples: &[TireSampleMirror],
    dt: f32,
    current_velocity_ws: Vec3,
    previous_fz: f32,
    config: TireCoreMirrorConfig,
) -> TireForcesMirror {
    let mut merged = Vec::with_capacity(shader_samples.len() + raycast_samples.len());
    merged.extend_from_slice(shader_samples);
    merged.extend_from_slice(raycast_samples);

    let patch = ContactPatchDataMirror::from_samples(&merged);
    let mut out = TireForcesMirror {
        contact_confidence: patch.patch_confidence,
        center_of_pressure_ws: {
            let cop = patch.center_of_pressure_ws(&merged);
            [cop.x, cop.y, cop.z]
        },
        ..TireForcesMirror::default()
    };

    if patch.patch_confidence < config.confidence_min_for_contact && raycast_samples.is_empty() {
        let t = (dt * config.emergency_fz_falloff_rate).clamp(0.0, 1.0);
        out.fz = previous_fz + (0.0 - previous_fz) * t;
        return out;
    }

    let base_k = 120000.0;
    let base_c = 3000.0;
    let pen_rate = if merged.is_empty() {
        0.0
    } else {
        merged.iter().map(|s| s.penetration_velocity).sum::<f32>() / merged.len() as f32
    };

    out.fz = (base_k * patch.penetration_avg + base_c * pen_rate).max(0.0);
    out.fx = -patch.average_slip.x * out.fz * 0.5;
    out.fy = -patch.average_slip.y * out.fz * 0.7;

    let mut tangential = Vec2 { x: out.fx, y: out.fy };
    let max_tangent = out.fz;
    if tangential.length() > max_tangent && tangential.length() > 0.0 {
        tangential = tangential.normalized();
        out.fx = tangential.x * max_tangent;
        out.fy = tangential.y * max_tangent;
    }

    out.mz = out.fy * patch.center_of_pressure_local.x;

    if dt > 0.0 {
        let f = Vec3 { x: out.fx, y: out.fz, z: out.fy };
        let delta_e = (f.dot(current_velocity_ws) * dt).abs();
        if delta_e > config.energy_delta_limit {
            let scale = config.energy_delta_limit / delta_e.max(1.0e-6);
            out.fx *= scale;
            out.fy *= scale;
            out.fz *= scale;
            out.mz *= scale;
        }
    }

    out
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

    #[test]
    fn contact_patch_from_samples_computes_weighted_values() {
        let samples = vec![
            TireSampleMirror {
                valid: true,
                contact_pos_local: Vec3 { x: 0.2, y: 0.0, z: 0.0 },
                contact_pos_ws: Vec3 { x: 1.0, y: 0.0, z: 0.0 },
                penetration: 0.02,
                confidence: 1.0,
                slip_vector: Vec2 { x: 0.4, y: 0.0 },
                ..TireSampleMirror::default()
            },
            TireSampleMirror {
                valid: true,
                contact_pos_local: Vec3 { x: -0.2, y: 0.0, z: 0.0 },
                contact_pos_ws: Vec3 { x: -1.0, y: 0.0, z: 0.0 },
                penetration: 0.02,
                confidence: 1.0,
                slip_vector: Vec2 { x: -0.4, y: 0.0 },
                ..TireSampleMirror::default()
            },
        ];
        let patch = ContactPatchDataMirror::from_samples(&samples);
        assert!((patch.patch_confidence - 1.0).abs() < 1.0e-6);
        assert!(patch.center_of_pressure_local.x.abs() < 1.0e-6);
        assert!(patch.average_slip.x.abs() < 1.0e-6);
    }

    #[test]
    fn step_wheel_mirror_emergency_falloff_when_no_ground() {
        let out = step_wheel_mirror(
            &[],
            &[],
            0.1,
            Vec3::default(),
            1000.0,
            TireCoreMirrorConfig::default(),
        );
        assert!(out.fz < 1000.0);
        assert!(out.fz >= 0.0);
    }

}
