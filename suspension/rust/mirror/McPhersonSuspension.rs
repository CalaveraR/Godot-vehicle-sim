use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/McPhersonSuspension.gd", class_name: "McPhersonSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct McPhersonSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct McPhersonSuspensionMirror;

impl McPhersonSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &McPhersonSuspensionState, _dt: f32) -> McPhersonSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &McPhersonSuspensionState) -> McPhersonSuspensionState { input.clone() }
    pub fn calculate_roll_center(&self, input: &McPhersonSuspensionState) -> McPhersonSuspensionState { input.clone() }
    pub fn calculate_instant_center(&self, input: &McPhersonSuspensionState) -> McPhersonSuspensionState { input.clone() }
    pub fn calculate_anti_features(&self, input: &McPhersonSuspensionState) -> McPhersonSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &McPhersonSuspensionState) -> McPhersonSuspensionState { input.clone() }
}
