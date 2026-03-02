use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/TurboSystem.gd", class_name: "TurboSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TurboSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TurboSystemMirror;

impl TurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TurboSystemState, _dt: f32) -> TurboSystemState { input.clone() }
    pub fn create_default_curves(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn create_induction_system(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn update_turbo(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn calculate_turbo_response(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn get_current_boost(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn get_intake_temp(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn update_turbo_inputs(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn set_engine_parameters(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn set_induction_type(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn configure_turbo(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn set_supercharger_settings(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn configure_twin_charged(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
    pub fn get_efficiency(&self, input: &TurboSystemState) -> TurboSystemState { input.clone() }
}
