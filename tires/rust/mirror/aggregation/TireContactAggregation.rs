use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/aggregation/TireContactAggregation.gd", class_name: "TireContactAggregation" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireContactAggregationState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireContactAggregationMirror;

impl TireContactAggregationMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireContactAggregationState, _dt: f32) -> TireContactAggregationState { input.clone() }
    pub fn normalize_weights(&self, input: &TireContactAggregationState) -> TireContactAggregationState { input.clone() }
    pub fn aggregate_patch(&self, input: &TireContactAggregationState) -> TireContactAggregationState { input.clone() }
    pub fn compute_effective_radius(&self, input: &TireContactAggregationState) -> TireContactAggregationState { input.clone() }
    pub fn build_unified_contact_data(&self, input: &TireContactAggregationState) -> TireContactAggregationState { input.clone() }
}
