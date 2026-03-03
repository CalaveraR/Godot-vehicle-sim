use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/contactpatchstate.gd", class_name: "ContactPatchstate" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchstateState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchstateMirror;

impl ContactPatchstateMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ContactPatchstateState, _dt: f32) -> ContactPatchstateState { input.clone() }
    pub fn rebuild_from_samples(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn recalculate(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn update_hysteresis(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn reset_hysteresis(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn reset(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_center_of_pressure_ws(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_average_normal_ws(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_average_slip_magnitude(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_lagged_slip_magnitude(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_average_slip_direction(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_lagged_slip_direction(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_hysteresis_debug_info(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_active_samples(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_sample_count(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn is_valid(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_timestamp(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_effective_grip_factor(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_grip_modulation_factors(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_thermal_state(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
    pub fn get_debug_info(&self, input: &ContactPatchstateState) -> ContactPatchstateState { input.clone() }
}
