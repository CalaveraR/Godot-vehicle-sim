use crate::{
    aggregate_patch_with_conventions, compute_effective_radius_with_conventions,
    normalize_weights_with_conventions, PatchAggregate, PatchSample, TireCoreConventions,
};

/// Pure reference mirror for `tires/godot/TireCoreReference.gd`.
pub fn normalize_weights(weights: &[f32], conventions: TireCoreConventions) -> Vec<f32> {
    normalize_weights_with_conventions(weights, conventions)
}

pub fn aggregate_patch(
    samples: &[PatchSample],
    conventions: TireCoreConventions,
) -> PatchAggregate {
    aggregate_patch_with_conventions(samples, conventions)
}

pub fn compute_effective_radius(
    tire_radius: f32,
    min_effective_radius: f32,
    vertical_load: f32,
    stiffness: f32,
    conventions: TireCoreConventions,
) -> f32 {
    compute_effective_radius_with_conventions(
        tire_radius,
        min_effective_radius,
        vertical_load,
        stiffness,
        conventions,
    )
}
