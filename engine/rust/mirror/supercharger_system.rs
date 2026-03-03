use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/supercharger_system.gd", class_name: "SuperchargerSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SuperchargerSystemState { pub current_boost: f32, pub current_efficiency: f32, pub supercharger_drag: f32, pub max_boost_pressure: f32 }
impl Default for SuperchargerSystemState { fn default() -> Self { Self { current_boost:1.0, current_efficiency:0.9, supercharger_drag:0.0, max_boost_pressure:1.8 } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SuperchargerSystemMirror;
impl SuperchargerSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update(&self, mut s: SuperchargerSystemState, rpm_n: f32, throttle: f32) -> SuperchargerSystemState {
        s.current_boost = 1.0 + rpm_n.clamp(0.0,1.0) * (s.max_boost_pressure - 1.0) * throttle.clamp(0.0,1.0);
        s.supercharger_drag = (s.current_boost - 1.0).max(0.0) * 0.15;
        s.current_efficiency = (0.92 - s.supercharger_drag * 0.2).clamp(0.7, 1.0);
        s
    }
}
