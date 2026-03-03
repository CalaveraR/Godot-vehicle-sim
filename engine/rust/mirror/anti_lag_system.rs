use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/anti_lag_system.gd", class_name: "AntiLagSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct AntiLagSystemState {
    pub active: bool,
    pub timer_s: f32,
    pub fuel_trim: f32,
    pub ignition_retard: f32,
    pub exhaust_temperature_c: f32,
    pub turbo_pressure_target: f32,
}
impl Default for AntiLagSystemState { fn default()->Self{ Self{ active:false,timer_s:0.0,fuel_trim:0.0,ignition_retard:0.0,exhaust_temperature_c:500.0,turbo_pressure_target:1.0 } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AntiLagSystemMirror;
impl AntiLagSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update(&self, mut s: AntiLagSystemState, delta: f32, throttle: f32) -> AntiLagSystemState {
        if s.active && throttle < 0.2 {
            s.timer_s += delta;
            s.fuel_trim = 0.12;
            s.ignition_retard = 12.0;
            s.exhaust_temperature_c += 80.0 * delta;
        } else {
            s.timer_s = 0.0;
            s.fuel_trim = 0.0;
            s.ignition_retard = 0.0;
            s.exhaust_temperature_c += (500.0 - s.exhaust_temperature_c) * (delta * 0.5).clamp(0.0,1.0);
        }
        s
    }
    pub fn is_temperature_safe(&self, s: &AntiLagSystemState) -> bool { s.exhaust_temperature_c < 1000.0 }
}
