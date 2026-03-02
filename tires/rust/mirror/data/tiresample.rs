use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/data/tiresample.gd", class_name: "TireSample" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireSampleState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireSampleMirror;

impl TireSampleMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireSampleState, _dt: f32) -> TireSampleState { input.clone() }
    pub fn reset(&self, input: &TireSampleState) -> TireSampleState { input.clone() }
    pub fn update_derived(&self, input: &TireSampleState) -> TireSampleState { input.clone() }
    pub fn copy(&self, input: &TireSampleState) -> TireSampleState { input.clone() }
}
