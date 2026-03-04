//! Canonical parity-facing name aligned with `suspension/godot/core/SuspensionCore.gd`.
//! Implementation delegates to `SuspensionCoreKernel.rs` to preserve current internals.

use super::SuspensionCoreContracts::{ClampFlags, EffectiveRadiusInput, EffectiveRadiusOutput, Vec3f};

pub fn compute_deformation_clamped(
    deformation: Vec3f,
    tire_induced_deformation: Vec3f,
) -> (Vec3f, ClampFlags) {
    super::SuspensionCoreKernel::compute_deformation_clamped(deformation, tire_induced_deformation)
}

pub fn compute_effective_radius(input: EffectiveRadiusInput) -> EffectiveRadiusOutput {
    super::SuspensionCoreKernel::compute_effective_radius(input)
}

pub fn compute_relaxation_factor(default_value: f32, curve_evaluated_value: Option<f32>) -> f32 {
    super::SuspensionCoreKernel::compute_relaxation_factor(default_value, curve_evaluated_value)
}

pub fn compute_lateral_deformation(curve_evaluated_value: Option<f32>) -> f32 {
    super::SuspensionCoreKernel::compute_lateral_deformation(curve_evaluated_value)
}
