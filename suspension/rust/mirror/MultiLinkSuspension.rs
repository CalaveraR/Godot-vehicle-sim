use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "suspension/godot/MultiLinkSuspension.gd", class_name: "MultiLinkSuspension" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct MultiLinkSuspensionState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct MultiLinkSuspensionMirror;

impl MultiLinkSuspensionMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &MultiLinkSuspensionState, _dt: f32) -> MultiLinkSuspensionState { input.clone() }
    pub fn calculate_specific_geometry(&self, input: &MultiLinkSuspensionState) -> MultiLinkSuspensionState { input.clone() }
    pub fn calculate_anti_features(&self, input: &MultiLinkSuspensionState) -> MultiLinkSuspensionState { input.clone() }
    pub fn get_suspension_type_name(&self, input: &MultiLinkSuspensionState) -> MultiLinkSuspensionState { input.clone() }
}
