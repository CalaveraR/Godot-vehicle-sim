use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/diesel_combustion.gd", class_name: "DieselCombustionSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct DieselCombustionSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct DieselCombustionSystemMirror;

impl DieselCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &DieselCombustionSystemState, _dt: f32) -> DieselCombustionSystemState { input.clone() }
    pub fn update_combustion_events(&self, input: &DieselCombustionSystemState) -> DieselCombustionSystemState { input.clone() }
}
