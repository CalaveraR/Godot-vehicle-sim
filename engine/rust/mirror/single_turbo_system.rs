use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/single_turbo_system.gd", class_name: "SingleTurboSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SingleTurboSystemState {
    pub current_boost: f32,
    pub current_efficiency: f32,
    pub turbo_response_rate: f32,
    pub boost_target: f32,
    pub vgt_position: f32,
    pub compressor_outlet_temp_c: f32,
    pub current_backpressure: f32,
    pub turbo_load_factor: f32,
    pub intake_temperature_c: f32,
    pub max_boost_pressure: f32,
    pub ambient_temp_c: f32,
}
impl Default for SingleTurboSystemState {
    fn default() -> Self { Self { current_boost:1.0,current_efficiency:0.85,turbo_response_rate:0.0,boost_target:1.0,vgt_position:0.5,compressor_outlet_temp_c:25.0,current_backpressure:1.0,turbo_load_factor:0.0,intake_temperature_c:25.0,max_boost_pressure:2.0,ambient_temp_c:25.0 } }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SingleTurboSystemMirror;
impl SingleTurboSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    fn smoothstep(e0:f32,e1:f32,x:f32)->f32{ let t=((x-e0)/(e1-e0).max(1e-6)).clamp(0.0,1.0); t*t*(3.0-2.0*t) }
    pub fn calculate_boost_target(&self, mut s: SingleTurboSystemState, rpm_n: f32) -> SingleTurboSystemState {
        s.boost_target = 1.0 + Self::smoothstep(0.15,0.75,rpm_n) * (s.max_boost_pressure - 1.0); s
    }
    pub fn apply_turbo_lag(&self, mut s: SingleTurboSystemState, delta: f32, rpm_n: f32) -> SingleTurboSystemState {
        let response = 1.0 + rpm_n * 8.0;
        s.current_boost += (s.boost_target - s.current_boost) * (delta * response).clamp(0.0,1.0);
        s.turbo_response_rate = response;
        s
    }
    pub fn update_turbo_efficiency(&self, mut s: SingleTurboSystemState, rpm_n: f32) -> SingleTurboSystemState {
        s.turbo_load_factor = (rpm_n * (s.current_boost - 1.0)).clamp(0.0,1.0);
        s.current_efficiency = (0.85 + 0.15 * (1.0 - (s.turbo_load_factor - 0.5).abs() * 2.0)).clamp(0.6,1.0);
        s
    }
}
