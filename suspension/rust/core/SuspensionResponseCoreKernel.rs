use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionResponseInput {
    pub lateral_g: f32,
    pub load_transfer_curve_eval: f32,
    pub bump_steer_curve_eval: f32,
    pub roll_center_curve_eval: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionResponseOutput {
    pub load_transfer: f32,
    pub dynamic_bump_steer: f32,
    pub roll_center_height: f32,
}

pub fn calculate_dynamic_response(input: SuspensionResponseInput) -> SuspensionResponseOutput {
    SuspensionResponseOutput {
        load_transfer: input.load_transfer_curve_eval * input.lateral_g.signum(),
        dynamic_bump_steer: input.bump_steer_curve_eval,
        roll_center_height: input.roll_center_curve_eval,
    }
}
