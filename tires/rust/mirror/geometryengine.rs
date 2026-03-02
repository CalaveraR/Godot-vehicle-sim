use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/geometryengine.gd", class_name: "GeometryEngine" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct GeometryEngineState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct GeometryEngineMirror;

impl GeometryEngineMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &GeometryEngineState, _dt: f32) -> GeometryEngineState { input.clone() }
    pub fn sample_contact(&self, input: &GeometryEngineState) -> GeometryEngineState { input.clone() }
}
