use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/staggered_turbo_system.gd", class_name: "StaggeredTurboSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum StaggeredMode { SizeDifference, ElectricAssist, SuperchargerPrimary }

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct StaggeredTurboSystemState { pub mode: StaggeredMode, pub current_boost: f32, pub current_efficiency: f32, pub electric_boost: f32, pub supercharger_boost: f32, pub turbo_boost: f32 }
impl Default for StaggeredTurboSystemState { fn default()->Self{ Self{ mode:StaggeredMode::SizeDifference,current_boost:1.0,current_efficiency:0.85,electric_boost:1.0,supercharger_boost:1.0,turbo_boost:1.0 } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct StaggeredTurboSystemMirror;
impl StaggeredTurboSystemMirror { pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update(&self, mut s: StaggeredTurboSystemState, rpm_n: f32) -> StaggeredTurboSystemState {
        match s.mode {
            StaggeredMode::SizeDifference => { s.current_boost = 1.0 + rpm_n * 0.9; }
            StaggeredMode::ElectricAssist => { s.current_boost = if rpm_n > 0.6 { s.electric_boost * s.turbo_boost } else { s.electric_boost }; }
            StaggeredMode::SuperchargerPrimary => { s.current_boost = s.supercharger_boost * s.turbo_boost; s.current_efficiency = 0.9; }
        }
        s
    }
}
