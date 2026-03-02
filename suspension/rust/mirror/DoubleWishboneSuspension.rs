use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/DoubleWishboneSuspension.gd", class_name: "DoubleWishboneSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct DoubleWishboneSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct DoubleWishboneSuspensionMirror;

impl DoubleWishboneSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &DoubleWishboneSuspensionState, _dt: f32) -> DoubleWishboneSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &DoubleWishboneSuspensionState) -> DoubleWishboneSuspensionState { input.clone() }
    pub fn calculate_roll_center(&self, input: &DoubleWishboneSuspensionState) -> DoubleWishboneSuspensionState { input.clone() }
    pub fn calculate_instant_center(&self, input: &DoubleWishboneSuspensionState) -> DoubleWishboneSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &DoubleWishboneSuspensionState) -> DoubleWishboneSuspensionState { input.clone() }
}
