use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/InductionSystem.gd", class_name: "InductionSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct InductionSystemState {
    pub current_boost: f32,
    pub current_efficiency: f32,
    pub turbo_spooled: bool,
    pub current_backpressure: f32,
    pub turbo_surge: bool,
    pub supercharger_drag: f32,
    pub intake_temperature_c: f32,
    pub turbo_load_factor: f32,
    pub redline_rpm: f32,
    pub ambient_temp_c: f32,
}
impl Default for InductionSystemState {
    fn default() -> Self { Self { current_boost: 1.0, current_efficiency: 1.0, turbo_spooled: false, current_backpressure: 1.0, turbo_surge: false, supercharger_drag: 0.0, intake_temperature_c: 25.0, turbo_load_factor: 0.0, redline_rpm: 7000.0, ambient_temp_c: 25.0 } }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct InductionSystemMirror;
impl InductionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update(&self, mut s: InductionSystemState, rpm: f32, throttle: f32) -> InductionSystemState {
        s.current_boost = 1.0 + (rpm / s.redline_rpm.max(1.0)) * 0.5;
        s.current_efficiency = 0.8 + throttle.clamp(0.0,1.0) * 0.2;
        s
    }
    pub fn apply_intercooler(&self, mut s: InductionSystemState) -> InductionSystemState {
        s.intake_temperature_c = s.ambient_temp_c + (s.intake_temperature_c - s.ambient_temp_c) * 0.7;
        s
    }
}
