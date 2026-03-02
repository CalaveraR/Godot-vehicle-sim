use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/single_turbo_system.gd", class_name: "SingleTurboSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SingleTurboSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SingleTurboSystemMirror;

impl SingleTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &SingleTurboSystemState, _dt: f32) -> SingleTurboSystemState { input.clone() }
    pub fn update(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn calculate_boost_target(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn apply_turbo_lag(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn update_vgt_position(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn calculate_backpressure(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn calculate_turbo_load_factor(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn update_turbo_efficiency(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn calculate_compressor_temperature(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn apply_intercooler(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn get_boost(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn get_intake_temp(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn get_data(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
    pub fn smoothstep(&self, input: &SingleTurboSystemState) -> SingleTurboSystemState { input.clone() }
}
