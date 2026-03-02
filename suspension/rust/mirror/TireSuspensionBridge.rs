use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/TireSuspensionBridge.gd", class_name: "TireSuspensionBridge" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireSuspensionBridgeState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireSuspensionBridgeMirror;

impl TireSuspensionBridgeMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireSuspensionBridgeState, _dt: f32) -> TireSuspensionBridgeState { input.clone() }
    pub fn apply_to_suspension(&self, input: &TireSuspensionBridgeState) -> TireSuspensionBridgeState { input.clone() }
}
