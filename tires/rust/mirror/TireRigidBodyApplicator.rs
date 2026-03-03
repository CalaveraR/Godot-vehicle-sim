use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/TireRigidBodyApplicator.gd", class_name: "TireRigidBodyApplicator" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireRigidBodyApplicatorState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireRigidBodyApplicatorMirror;

impl TireRigidBodyApplicatorMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireRigidBodyApplicatorState, _dt: f32) -> TireRigidBodyApplicatorState { input.clone() }
    pub fn apply(&self, input: &TireRigidBodyApplicatorState) -> TireRigidBodyApplicatorState { input.clone() }
}
