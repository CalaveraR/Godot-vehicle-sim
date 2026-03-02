use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/core/TireForces.gd", class_name: "TireForces" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireForcesState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireForcesMirror;

impl TireForcesMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireForcesState, _dt: f32) -> TireForcesState { input.clone() }
    pub fn to_dict(&self, input: &TireForcesState) -> TireForcesState { input.clone() }
    pub fn to_json(&self, input: &TireForcesState) -> TireForcesState { input.clone() }
}
