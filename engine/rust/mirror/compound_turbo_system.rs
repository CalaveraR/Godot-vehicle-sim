use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/compound_turbo_system.gd", class_name: "CompoundTurboSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CompoundTurboSystemState {
    pub hp_boost: f32,
    pub lp_boost: f32,
    pub current_boost: f32,
    pub intermediate_pressure: f32,
    pub current_efficiency: f32,
    pub intake_temperature_c: f32,
    pub max_boost_pressure: f32,
}
impl Default for CompoundTurboSystemState { fn default()->Self{ Self{ hp_boost:1.0,lp_boost:1.0,current_boost:1.0,intermediate_pressure:1.0,current_efficiency:0.82,intake_temperature_c:25.0,max_boost_pressure:2.4 } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CompoundTurboSystemMirror;
impl CompoundTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update_hp_stage(&self, mut s: CompoundTurboSystemState, dt: f32, rpm_n: f32) -> CompoundTurboSystemState {
        let target = 1.0 + ((rpm_n/0.3).clamp(0.0,1.0)) * 0.8;
        s.hp_boost += (target - s.hp_boost) * (dt * (10.0 + 15.0 * rpm_n)).clamp(0.0,1.0);
        s.intermediate_pressure = s.hp_boost;
        s
    }
    pub fn update_lp_stage(&self, mut s: CompoundTurboSystemState, dt: f32, rpm_n: f32) -> CompoundTurboSystemState {
        let target = if rpm_n > 0.4 { 1.0 + ((rpm_n-0.4)/0.4).clamp(0.0,1.0) * (s.max_boost_pressure - 1.0) } else { 1.0 };
        s.lp_boost += (target - s.lp_boost) * (dt * (1.0 + 3.0 * rpm_n)).clamp(0.0,1.0);
        s.current_boost = s.hp_boost * s.lp_boost;
        s.current_efficiency = (0.82 - ((s.current_boost-1.0)*0.05)).clamp(0.6, 0.95);
        s
    }
}
