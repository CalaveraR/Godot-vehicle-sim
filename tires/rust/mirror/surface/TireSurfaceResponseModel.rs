use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/surface/TireSurfaceResponseModel.gd", class_name: "TireSurfaceResponseModel" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireSurfaceResponseModelState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireSurfaceResponseModelMirror;

impl TireSurfaceResponseModelMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireSurfaceResponseModelState, _dt: f32) -> TireSurfaceResponseModelState { input.clone() }
    pub fn calculate_local_grip(&self, input: &TireSurfaceResponseModelState) -> TireSurfaceResponseModelState { input.clone() }
    pub fn update_wear_and_temperature(&self, input: &TireSurfaceResponseModelState) -> TireSurfaceResponseModelState { input.clone() }
    pub fn update_aquaplaning_effects(&self, input: &TireSurfaceResponseModelState) -> TireSurfaceResponseModelState { input.clone() }
    pub fn update_zone_grip_from_tire_wear(&self, input: &TireSurfaceResponseModelState) -> TireSurfaceResponseModelState { input.clone() }
    pub fn get_clipping_ratio(&self, input: &TireSurfaceResponseModelState) -> TireSurfaceResponseModelState { input.clone() }
    pub fn apply_clipping_forces(&self, input: &TireSurfaceResponseModelState) -> TireSurfaceResponseModelState { input.clone() }
}
