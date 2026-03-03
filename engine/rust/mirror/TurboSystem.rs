use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/TurboSystem.gd", class_name: "TurboSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum InductionType { NaturallyAspirated, Supercharged, Turbocharger, TwinTurbo, TwinTurboStaggered, CompoundTurbo, ElectricTurbo, TwinCharged }

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TurboSystemState {
    pub induction_type: InductionType,
    pub idle_rpm: f32,
    pub redline_rpm: f32,
    pub engine_rpm: f32,
    pub engine_throttle: f32,
    pub max_boost_pressure: f32,
    pub current_boost: f32,
    pub efficiency: f32,
    pub intake_temperature_c: f32,
}
impl Default for TurboSystemState {
    fn default() -> Self { Self { induction_type: InductionType::Turbocharger, idle_rpm: 800.0, redline_rpm: 7000.0, engine_rpm: 800.0, engine_throttle: 0.0, max_boost_pressure: 2.0, current_boost: 1.0, efficiency: 0.85, intake_temperature_c: 25.0 } }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TurboSystemMirror;
impl TurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn get_rpm_normalized(&self, s: &TurboSystemState) -> f32 { ((s.engine_rpm - s.idle_rpm) / (s.redline_rpm - s.idle_rpm).max(1.0)).clamp(0.0,1.2) }
    pub fn update_turbo_inputs(&self, mut s: TurboSystemState, rpm: f32, throttle: f32) -> TurboSystemState { s.engine_rpm = rpm; s.engine_throttle = throttle.clamp(0.0,1.0); s }
    pub fn calculate_turbo_response(&self, s: &TurboSystemState) -> f32 {
        let rn = self.get_rpm_normalized(s);
        (rn * s.engine_throttle).clamp(0.0, 1.0)
    }
}
