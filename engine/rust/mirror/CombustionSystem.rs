use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/CombustionSystem.gd", class_name: "CombustionSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CombustionSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CombustionSystemMirror;

impl CombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &CombustionSystemState, _dt: f32) -> CombustionSystemState { input.clone() }
    pub fn create_combustion_curves(&self, input: &CombustionSystemState) -> CombustionSystemState { input.clone() }
    pub fn update(&self, input: &CombustionSystemState) -> CombustionSystemState { input.clone() }
    pub fn calculate_combustion_efficiency(&self, input: &CombustionSystemState) -> CombustionSystemState { input.clone() }
    pub fn calculate_combustion_torque(&self, input: &CombustionSystemState) -> CombustionSystemState { input.clone() }
    pub fn calculate_combustion_temperature(&self, input: &CombustionSystemState) -> CombustionSystemState { input.clone() }
}
