use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/applyinfluencetoshaderstate.gd", class_name: "ApplyInfluenceToShaderState" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ApplyInfluenceToShaderStateState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ApplyInfluenceToShaderStateMirror;

impl ApplyInfluenceToShaderStateMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ApplyInfluenceToShaderStateState, _dt: f32) -> ApplyInfluenceToShaderStateState { input.clone() }
    pub fn apply(&self, input: &ApplyInfluenceToShaderStateState) -> ApplyInfluenceToShaderStateState { input.clone() }
}
