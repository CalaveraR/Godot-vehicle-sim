use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/twin_turbo_system.gd", class_name: "TwinTurboSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwinTurboSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwinTurboSystemMirror;

impl TwinTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TwinTurboSystemState, _dt: f32) -> TwinTurboSystemState { input.clone() }
    pub fn calculate_boost_target(&self, input: &TwinTurboSystemState) -> TwinTurboSystemState { input.clone() }
    pub fn apply_turbo_lag(&self, input: &TwinTurboSystemState) -> TwinTurboSystemState { input.clone() }
    pub fn get_data(&self, input: &TwinTurboSystemState) -> TwinTurboSystemState { input.clone() }
}
