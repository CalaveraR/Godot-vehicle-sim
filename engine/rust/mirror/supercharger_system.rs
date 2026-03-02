use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/supercharger_system.gd", class_name: "SuperchargerSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SuperchargerSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SuperchargerSystemMirror;

impl SuperchargerSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &SuperchargerSystemState, _dt: f32) -> SuperchargerSystemState { input.clone() }
    pub fn update(&self, input: &SuperchargerSystemState) -> SuperchargerSystemState { input.clone() }
    pub fn get_data(&self, input: &SuperchargerSystemState) -> SuperchargerSystemState { input.clone() }
}
