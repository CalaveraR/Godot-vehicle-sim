use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/staggered_turbo_system.gd", class_name: "StaggeredTurboSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct StaggeredTurboSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct StaggeredTurboSystemMirror;

impl StaggeredTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &StaggeredTurboSystemState, _dt: f32) -> StaggeredTurboSystemState { input.clone() }
    pub fn update(&self, input: &StaggeredTurboSystemState) -> StaggeredTurboSystemState { input.clone() }
    pub fn update_electric_assist(&self, input: &StaggeredTurboSystemState) -> StaggeredTurboSystemState { input.clone() }
    pub fn update_supercharger_primary(&self, input: &StaggeredTurboSystemState) -> StaggeredTurboSystemState { input.clone() }
    pub fn get_data(&self, input: &StaggeredTurboSystemState) -> StaggeredTurboSystemState { input.clone() }
}
