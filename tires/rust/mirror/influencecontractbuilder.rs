use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/influencecontractbuilder.gd", class_name: "InfluenceContractBuilder" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct InfluenceContractBuilderState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct InfluenceContractBuilderMirror;

impl InfluenceContractBuilderMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &InfluenceContractBuilderState, _dt: f32) -> InfluenceContractBuilderState { input.clone() }
    pub fn build_from_decision(&self, input: &InfluenceContractBuilderState) -> InfluenceContractBuilderState { input.clone() }
    pub fn build(&self, input: &InfluenceContractBuilderState) -> InfluenceContractBuilderState { input.clone() }
}
