use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/compound_turbo_system.gd", class_name: "CompoundTurboSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CompoundTurboSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CompoundTurboSystemMirror;

impl CompoundTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &CompoundTurboSystemState, _dt: f32) -> CompoundTurboSystemState { input.clone() }
    pub fn update(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
    pub fn update_hp_stage(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
    pub fn update_lp_stage(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
    pub fn calculate_temperatures(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
    pub fn calculate_turbo_load_factor(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
    pub fn update_turbo_efficiency(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
    pub fn get_data(&self, input: &CompoundTurboSystemState) -> CompoundTurboSystemState { input.clone() }
}
