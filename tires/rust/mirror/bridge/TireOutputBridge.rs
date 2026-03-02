use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/bridge/TireOutputBridge.gd", class_name: "TireOutputBridge" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireOutputBridgeState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireOutputBridgeMirror;

impl TireOutputBridgeMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireOutputBridgeState, _dt: f32) -> TireOutputBridgeState { input.clone() }
    pub fn to_world_force(&self, input: &TireOutputBridgeState) -> TireOutputBridgeState { input.clone() }
    pub fn to_world_point(&self, input: &TireOutputBridgeState) -> TireOutputBridgeState { input.clone() }
    pub fn build_apply_payload(&self, input: &TireOutputBridgeState) -> TireOutputBridgeState { input.clone() }
}
