use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/AirSuspension.gd", class_name: "AirSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AirSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AirSuspensionMirror;

impl AirSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &AirSuspensionState, _dt: f32) -> AirSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &AirSuspensionState) -> AirSuspensionState { input.clone() }
    pub fn adjust_ride_height(&self, input: &AirSuspensionState) -> AirSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &AirSuspensionState) -> AirSuspensionState { input.clone() }
}
