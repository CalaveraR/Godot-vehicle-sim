use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/runtime/TireContactRuntime.gd", class_name: "TireContactRuntime" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireContactRuntimeState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireContactRuntimeMirror;

impl TireContactRuntimeMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireContactRuntimeState, _dt: f32) -> TireContactRuntimeState { input.clone() }
    pub fn update_contact_data(&self, input: &TireContactRuntimeState) -> TireContactRuntimeState { input.clone() }
    pub fn apply_to_wheel(&self, input: &TireContactRuntimeState) -> TireContactRuntimeState { input.clone() }
    pub fn apply_to_tire_system(&self, input: &TireContactRuntimeState) -> TireContactRuntimeState { input.clone() }
    pub fn apply_clipping_overlaps(&self, input: &TireContactRuntimeState) -> TireContactRuntimeState { input.clone() }
}
