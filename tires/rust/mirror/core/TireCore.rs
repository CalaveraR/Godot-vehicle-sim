use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/core/TireCore.gd", class_name: "TireCore" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireCoreState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireCoreMirror;

impl TireCoreMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireCoreState, _dt: f32) -> TireCoreState { input.clone() }
    pub fn step_wheel(&self, input: &TireCoreState) -> TireCoreState { input.clone() }
}
