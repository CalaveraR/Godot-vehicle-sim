use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/InductionSystem.gd", class_name: "InductionSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct InductionSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct InductionSystemMirror;

impl InductionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &InductionSystemState, _dt: f32) -> InductionSystemState { input.clone() }
    pub fn update(&self, input: &InductionSystemState) -> InductionSystemState { input.clone() }
    pub fn get_boost(&self, input: &InductionSystemState) -> InductionSystemState { input.clone() }
    pub fn get_intake_temp(&self, input: &InductionSystemState) -> InductionSystemState { input.clone() }
    pub fn apply_intercooler(&self, input: &InductionSystemState) -> InductionSystemState { input.clone() }
    pub fn get_data(&self, input: &InductionSystemState) -> InductionSystemState { input.clone() }
}
