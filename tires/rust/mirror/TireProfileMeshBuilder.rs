use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/TireProfileMeshBuilder.gd", class_name: "TireProfileMeshBuilder" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireProfileMeshBuilderState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireProfileMeshBuilderMirror;

impl TireProfileMeshBuilderMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireProfileMeshBuilderState, _dt: f32) -> TireProfileMeshBuilderState { input.clone() }
    pub fn build_profile_mesh(&self, input: &TireProfileMeshBuilderState) -> TireProfileMeshBuilderState { input.clone() }
}
