use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/two_stroke_combustion.gd", class_name: "TwoStrokeCombustionSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwoStrokeCombustionSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwoStrokeCombustionSystemMirror;

impl TwoStrokeCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TwoStrokeCombustionSystemState, _dt: f32) -> TwoStrokeCombustionSystemState { input.clone() }
    pub fn update_combustion_events(&self, input: &TwoStrokeCombustionSystemState) -> TwoStrokeCombustionSystemState { input.clone() }
}
