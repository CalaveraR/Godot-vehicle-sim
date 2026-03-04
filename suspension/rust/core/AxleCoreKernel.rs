use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SolidAxleInput {
    pub load_left: f32,
    pub load_right: f32,
    pub axle_stiffness: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SolidAxleOutput {
    pub deformation_y_left: f32,
    pub deformation_y_right: f32,
    pub balanced_load: f32,
}

pub fn compute_solid_axle(input: SolidAxleInput) -> SolidAxleOutput {
    let avg_load = (input.load_left + input.load_right) * 0.5;
    let k = input.axle_stiffness.max(1.0e-6);
    SolidAxleOutput {
        deformation_y_left: (input.load_left - avg_load) / k,
        deformation_y_right: (input.load_right - avg_load) / k,
        balanced_load: avg_load,
    }
}
