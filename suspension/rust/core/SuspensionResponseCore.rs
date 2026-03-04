//! Canonical parity-facing name aligned with `suspension/godot/core/SuspensionResponseCore.gd`.
//! Implementation delegates to `SuspensionResponseCoreKernel.rs`.

pub use super::SuspensionResponseCoreKernel::{SuspensionResponseInput, SuspensionResponseOutput};

pub fn calculate_dynamic_response(input: SuspensionResponseInput) -> SuspensionResponseOutput {
    super::SuspensionResponseCoreKernel::calculate_dynamic_response(input)
}
