use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/twin_charged_system.gd", class_name: "TwinChargedSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TwinChargedSystemState {
    pub supercharger_boost: f32,
    pub turbo_boost: f32,
    pub current_boost: f32,
    pub current_efficiency: f32,
    pub transition_rpm: f32,
    pub supercharger_active: bool,
}
impl Default for TwinChargedSystemState { fn default() -> Self { Self { supercharger_boost:1.2, turbo_boost:1.0, current_boost:1.0, current_efficiency:0.9, transition_rpm:3500.0, supercharger_active:true } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TwinChargedSystemMirror;
impl TwinChargedSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update_active_system(&self, mut s: TwinChargedSystemState, rpm: f32) -> TwinChargedSystemState { s.supercharger_active = rpm < s.transition_rpm; s }
    pub fn combine_systems(&self, mut s: TwinChargedSystemState, rpm: f32) -> TwinChargedSystemState {
        let blend = ((rpm - s.transition_rpm + 500.0)/1000.0).clamp(0.0,1.0);
        s.current_boost = s.supercharger_boost * (1.0 - blend) + s.turbo_boost * blend;
        s.current_efficiency = 0.92 - blend * 0.05;
        s
    }
}
