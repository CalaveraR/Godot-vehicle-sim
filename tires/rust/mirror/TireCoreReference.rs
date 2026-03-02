use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/TireCoreReference.gd", class_name: "TireCoreReference" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireCoreReferenceState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireCoreReferenceMirror;

impl TireCoreReferenceMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireCoreReferenceState, _dt: f32) -> TireCoreReferenceState { input.clone() }
}
