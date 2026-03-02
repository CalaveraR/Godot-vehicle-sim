#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PatchSample {
    pub weight: f32,
    pub penetration: f32,
    pub slip_x: f32,
    pub slip_y: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PatchAggregate {
    pub contact_confidence: f32,
    pub penetration_avg: f32,
    pub penetration_max: f32,
    pub slip_x_avg: f32,
    pub slip_y_avg: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TireCoreConventions {
    pub epsilon: f32,
    pub min_stiffness: f32,
    pub min_positive_weight: f32,
    pub contact_penetration_threshold: f32,
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
}
