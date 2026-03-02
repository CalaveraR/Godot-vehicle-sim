use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/contactpatchbuilder.gd", class_name: "ContactPatchBuilder" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchBuilderState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ContactPatchBuilderMirror;

impl ContactPatchBuilderMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ContactPatchBuilderState, _dt: f32) -> ContactPatchBuilderState { input.clone() }
    pub fn build_contact_patch(&self, input: &ContactPatchBuilderState) -> ContactPatchBuilderState { input.clone() }
    pub fn build_contact_patch_data(&self, input: &ContactPatchBuilderState) -> ContactPatchBuilderState { input.clone() }
}
