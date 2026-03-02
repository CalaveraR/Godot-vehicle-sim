use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/four_stroke_combustion.gd", class_name: "FourStrokeCombustionSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct FourStrokeCombustionSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct FourStrokeCombustionSystemMirror;

impl FourStrokeCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &FourStrokeCombustionSystemState, _dt: f32) -> FourStrokeCombustionSystemState { input.clone() }
    pub fn update_combustion_events(&self, input: &FourStrokeCombustionSystemState) -> FourStrokeCombustionSystemState { input.clone() }
}
