use crate::{contact_patch_data::ContactPatchData, TireCoreConventions, TireSampleMirror};

/// Numeric-only portion of `tires/aggregation/TireContactAggregation.gd`.
/// Scene glue and fallback decisions remain in Godot.
pub fn aggregate_numeric_patch(
    samples: &[TireSampleMirror],
    conventions: TireCoreConventions,
) -> ContactPatchData {
    ContactPatchData::from_samples(samples, conventions)
}
