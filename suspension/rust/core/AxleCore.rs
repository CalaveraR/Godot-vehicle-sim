//! Canonical parity-facing name aligned with `suspension/godot/core/AxleCore.gd`.
//! Implementation delegates to `AxleCoreKernel.rs`.

pub use super::AxleCoreKernel::{SolidAxleInput, SolidAxleOutput};

pub fn compute_solid_axle(input: SolidAxleInput) -> SolidAxleOutput {
    super::AxleCoreKernel::compute_solid_axle(input)
}
