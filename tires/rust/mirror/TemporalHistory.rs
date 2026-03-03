use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/TemporalHistory.gd", class_name: "TemporalHistory" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TemporalHistoryState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TemporalHistoryMirror;

impl TemporalHistoryMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TemporalHistoryState, _dt: f32) -> TemporalHistoryState { input.clone() }
    pub fn set_max_frames(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn is_valid(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_frame_count(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_time_span(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn add_frame(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn reset(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn clear_old_frames(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_penetration_velocity(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_slip_velocity(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_confidence_velocity(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_normal_angular_velocity(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_penetration_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_slip_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_confidence_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_normal_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_overall_temporal_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_max_penetration_variation(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_slip_vector_direction_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_normal_direction_consistency(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_contact_duration(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_contact_stability(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_temporal_stability(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_average_penetration(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_penetration_variance(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_debug_info(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
    pub fn get_frames_debug(&self, input: &TemporalHistoryState) -> TemporalHistoryState { input.clone() }
}
