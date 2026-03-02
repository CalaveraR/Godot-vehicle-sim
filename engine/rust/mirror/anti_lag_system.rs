use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/anti_lag_system.gd", class_name: "AntiLagSystem" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AntiLagSystemState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AntiLagSystemMirror;

impl AntiLagSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &AntiLagSystemState, _dt: f32) -> AntiLagSystemState { input.clone() }
    pub fn update(&self, input: &AntiLagSystemState) -> AntiLagSystemState { input.clone() }
    pub fn get_anti_lag_data(&self, input: &AntiLagSystemState) -> AntiLagSystemState { input.clone() }
    pub fn set_turbo_pressure_target(&self, input: &AntiLagSystemState) -> AntiLagSystemState { input.clone() }
    pub fn is_temperature_safe(&self, input: &AntiLagSystemState) -> AntiLagSystemState { input.clone() }
    pub fn get_turbo_stress_level(&self, input: &AntiLagSystemState) -> AntiLagSystemState { input.clone() }
}
