use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/ContactPatch.gd", class_name: "ContactPatch" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchMirror;

impl ContactPatchMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ContactPatchState, _dt: f32) -> ContactPatchState { input.clone() }
    pub fn rebuild_from_samples(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn recalculate(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn update_hysteresis(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn reset_hysteresis(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_center_of_pressure_ws(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_average_normal_ws(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_average_slip_magnitude(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_lagged_slip_magnitude(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_average_slip_direction(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_lagged_slip_direction(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_hysteresis_debug_info(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_active_samples(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_sample_count(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn is_valid(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_timestamp(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_effective_grip_factor(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_grip_modulation_factors(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_thermal_state(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn get_debug_info(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
    pub fn reset(&self, input: &ContactPatchState) -> ContactPatchState { input.clone() }
}
