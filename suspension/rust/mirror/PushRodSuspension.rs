use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/PushRodSuspension.gd", class_name: "PushRodSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PushRodSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PushRodSuspensionMirror;

impl PushRodSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &PushRodSuspensionState, _dt: f32) -> PushRodSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &PushRodSuspensionState) -> PushRodSuspensionState { input.clone() }
    pub fn calculate_anti_features(&self, input: &PushRodSuspensionState) -> PushRodSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &PushRodSuspensionState) -> PushRodSuspensionState { input.clone() }
}
