use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/twin_charged_system.gd", class_name: "TwinChargedSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwinChargedSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwinChargedSystemMirror;

impl TwinChargedSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TwinChargedSystemState, _dt: f32) -> TwinChargedSystemState { input.clone() }
    pub fn update(&self, input: &TwinChargedSystemState) -> TwinChargedSystemState { input.clone() }
    pub fn update_active_system(&self, input: &TwinChargedSystemState) -> TwinChargedSystemState { input.clone() }
    pub fn combine_systems(&self, input: &TwinChargedSystemState) -> TwinChargedSystemState { input.clone() }
    pub fn get_data(&self, input: &TwinChargedSystemState) -> TwinChargedSystemState { input.clone() }
}
