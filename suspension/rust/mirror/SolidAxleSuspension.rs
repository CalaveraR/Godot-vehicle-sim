use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/SolidAxleSuspension.gd", class_name: "SolidAxleSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SolidAxleSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SolidAxleSuspensionMirror;

impl SolidAxleSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &SolidAxleSuspensionState, _dt: f32) -> SolidAxleSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &SolidAxleSuspensionState) -> SolidAxleSuspensionState { input.clone() }
    pub fn calculate_roll_center(&self, input: &SolidAxleSuspensionState) -> SolidAxleSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &SolidAxleSuspensionState) -> SolidAxleSuspensionState { input.clone() }
}
