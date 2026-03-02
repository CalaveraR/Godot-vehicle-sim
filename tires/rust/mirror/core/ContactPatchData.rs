use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/core/ContactPatchData.gd", class_name: "ContactPatchData" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchDataState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchDataMirror;

impl ContactPatchDataMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ContactPatchDataState, _dt: f32) -> ContactPatchDataState { input.clone() }
    pub fn get_center_of_pressure_ws(&self, input: &ContactPatchDataState) -> ContactPatchDataState { input.clone() }
}
