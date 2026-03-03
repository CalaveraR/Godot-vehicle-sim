#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

use crate::{
    normalize_weights_with_conventions, TireCoreConventions, TireSampleMirror, Vec2, Vec3,
};

/// Rust mirror of `tires/godot/core/ContactPatchData.gd` focused on pure numeric aggregation.
#[derive(Debug, Clone, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct ContactPatchData {
    pub patch_confidence: f32,
    pub center_of_pressure_local: Vec3,
    pub avg_normal_local: Vec3,
    pub penetration_avg: f32,
    pub penetration_max: f32,
    pub average_slip: Vec2,
    pub normalized_weights: Vec<f32>,
    pub total_weight: f32,
}

impl Default for ContactPatchData {
    fn default() -> Self {
        Self {
            patch_confidence: 0.0,
            center_of_pressure_local: Vec3::default(),
            avg_normal_local: Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            },
            penetration_avg: 0.0,
            penetration_max: 0.0,
            average_slip: Vec2::default(),
            normalized_weights: vec![],
            total_weight: 0.0,
        }
    }
}

impl ContactPatchData {
    pub fn from_samples(samples: &[TireSampleMirror], conventions: TireCoreConventions) -> Self {
        if samples.is_empty() {
            return Self::default();
        }

        let mut weighted_pos = Vec3::default();
        let mut weighted_normal = Vec3::default();
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
            weighted_pos.x += sample.contact_pos_local.x * w;
            weighted_pos.y += sample.contact_pos_local.y * w;
            weighted_pos.z += sample.contact_pos_local.z * w;

            weighted_normal.x += sample.contact_normal_local.x * w;
            weighted_normal.y += sample.contact_normal_local.y * w;
            weighted_normal.z += sample.contact_normal_local.z * w;

            weighted_slip.x += sample.slip_vector.x * w;
            weighted_slip.y += sample.slip_vector.y * w;

            penetration_sum += sample.penetration;
            penetration_max = penetration_max.max(sample.penetration);
            conf_sum += sample.confidence;
            total_weight += w;
            valid_count += 1.0;
        }

        let normalized_weights = normalize_weights_with_conventions(&raw_weights, conventions);
        if total_weight <= 0.0 || valid_count == 0.0 {
            return Self {
                normalized_weights,
                ..Self::default()
            };
        }

        let mut avg_normal = Vec3 {
            x: weighted_normal.x / total_weight,
            y: weighted_normal.y / total_weight,
            z: weighted_normal.z / total_weight,
        };
        let n_len = (avg_normal.x * avg_normal.x
            + avg_normal.y * avg_normal.y
            + avg_normal.z * avg_normal.z)
            .sqrt();
        if n_len > conventions.epsilon {
            avg_normal.x /= n_len;
            avg_normal.y /= n_len;
            avg_normal.z /= n_len;
        } else {
            avg_normal = Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            };
        }

        Self {
            patch_confidence: (conf_sum / valid_count).clamp(0.0, 1.0),
            center_of_pressure_local: Vec3 {
                x: weighted_pos.x / total_weight,
                y: weighted_pos.y / total_weight,
                z: weighted_pos.z / total_weight,
            },
            avg_normal_local: avg_normal,
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
        if samples.is_empty() || self.normalized_weights.is_empty() {
            return Vec3::default();
        }
        let mut acc = Vec3::default();
        for (s, w) in samples.iter().zip(self.normalized_weights.iter().copied()) {
            acc.x += s.contact_pos_ws.x * w;
            acc.y += s.contact_pos_ws.y * w;
            acc.z += s.contact_pos_ws.z * w;
        }
        acc
    }
}
