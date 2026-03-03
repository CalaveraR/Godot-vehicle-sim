use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/data/WheelState.gd", class_name: "WheelState" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct WheelStateState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct WheelStateMirror;

impl WheelStateMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &WheelStateState, _dt: f32) -> WheelStateState { input.clone() }
    pub fn to_dict(&self, input: &WheelStateState) -> WheelStateState { input.clone() }
    pub fn to_json(&self, input: &WheelStateState) -> WheelStateState { input.clone() }
}
