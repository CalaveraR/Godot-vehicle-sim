use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/bridge/TireInputBridge.gd", class_name: "TireInputBridge" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireInputBridgeState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireInputBridgeMirror;

impl TireInputBridgeMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireInputBridgeState, _dt: f32) -> TireInputBridgeState { input.clone() }
    pub fn build_wheel_state(&self, input: &TireInputBridgeState) -> TireInputBridgeState { input.clone() }
    pub fn merge_samples(&self, input: &TireInputBridgeState) -> TireInputBridgeState { input.clone() }
}
