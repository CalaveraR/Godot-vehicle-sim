use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/EnginePhysics.gd", class_name: "EnginePhysics" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EnginePhysicsState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EnginePhysicsMirror;

impl EnginePhysicsMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &EnginePhysicsState, _dt: f32) -> EnginePhysicsState { input.clone() }
}
