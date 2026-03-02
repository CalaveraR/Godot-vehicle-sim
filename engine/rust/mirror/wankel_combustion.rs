use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/wankel_combustion.gd", class_name: "WankelCombustionSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct WankelCombustionSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct WankelCombustionSystemMirror;

impl WankelCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &WankelCombustionSystemState, _dt: f32) -> WankelCombustionSystemState { input.clone() }
    pub fn update_combustion_events(&self, input: &WankelCombustionSystemState) -> WankelCombustionSystemState { input.clone() }
}
