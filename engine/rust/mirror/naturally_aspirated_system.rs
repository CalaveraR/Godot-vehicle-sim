use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/naturally_aspirated_system.gd", class_name: "NaturallyAspiratedSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct NaturallyAspiratedSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct NaturallyAspiratedSystemMirror;

impl NaturallyAspiratedSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &NaturallyAspiratedSystemState, _dt: f32) -> NaturallyAspiratedSystemState { input.clone() }
    pub fn update(&self, input: &NaturallyAspiratedSystemState) -> NaturallyAspiratedSystemState { input.clone() }
    pub fn get_boost(&self, input: &NaturallyAspiratedSystemState) -> NaturallyAspiratedSystemState { input.clone() }
    pub fn get_intake_temp(&self, input: &NaturallyAspiratedSystemState) -> NaturallyAspiratedSystemState { input.clone() }
    pub fn get_data(&self, input: &NaturallyAspiratedSystemState) -> NaturallyAspiratedSystemState { input.clone() }
}
