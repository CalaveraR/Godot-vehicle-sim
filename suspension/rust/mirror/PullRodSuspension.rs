use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/PullRodSuspension.gd", class_name: "PullRodSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PullRodSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PullRodSuspensionMirror;

impl PullRodSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &PullRodSuspensionState, _dt: f32) -> PullRodSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &PullRodSuspensionState) -> PullRodSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &PullRodSuspensionState) -> PullRodSuspensionState { input.clone() }
}
