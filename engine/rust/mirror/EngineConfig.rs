use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/EngineConfig.gd", class_name: "EngineConfig" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EngineConfigState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EngineConfigMirror;

impl EngineConfigMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &EngineConfigState, _dt: f32) -> EngineConfigState { input.clone() }
}
