use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/ContactConfidenceModel.gd", class_name: "ContactConfidenceModel" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactConfidenceModelState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactConfidenceModelMirror;

impl ContactConfidenceModelMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ContactConfidenceModelState, _dt: f32) -> ContactConfidenceModelState { input.clone() }
    pub fn set_values(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn set_combine_mode(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn combine(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn update_shader_confidence(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn update_raycast_confidence(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn update_temporal_consistency(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn update_spatial_coherence(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn update_physical_coherence(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn decay(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn reset(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn invalidate(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn clear_cache(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn reset_history(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn is_reliable(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_confidence(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn is_valid(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_primary_confidence(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_stability_score(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_weakest_factor(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn compute_from_patch(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn should_use_fallback(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_regime(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_debug_info(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn get_summary(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn clone(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
    pub fn lerp_from(&self, input: &ContactConfidenceModelState) -> ContactConfidenceModelState { input.clone() }
}
