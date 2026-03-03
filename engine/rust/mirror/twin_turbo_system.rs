use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/twin_turbo_system.gd", class_name: "TwinTurboSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TwinTurboSystemState { pub current_boost: f32, pub boost_target: f32, pub max_boost_pressure: f32 }
impl Default for TwinTurboSystemState { fn default() -> Self { Self { current_boost:1.0, boost_target:1.0, max_boost_pressure:2.0 } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwinTurboSystemMirror;
impl TwinTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn calculate_boost_target(&self, mut s: TwinTurboSystemState, rpm_n: f32) -> TwinTurboSystemState {
        s.boost_target = 1.0 + (rpm_n * (s.max_boost_pressure - 1.0)); s
    }
    pub fn apply_turbo_lag(&self, mut s: TwinTurboSystemState, delta: f32, rpm_n: f32) -> TwinTurboSystemState {
        let response = 2.0 + rpm_n * 10.0;
        s.current_boost += (s.boost_target - s.current_boost) * (delta * response).clamp(0.0,1.0); s
    }
}
