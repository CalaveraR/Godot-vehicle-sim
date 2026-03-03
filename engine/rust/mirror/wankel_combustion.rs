use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/wankel_combustion.gd", class_name: "WankelCombustionSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct WankelCombustionSystemMirror;
impl WankelCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update_combustion_events(&self, chambers: u32, current_angle_deg: f32) -> u32 {
        let events_per_rotor = 3u32;
        let angle_per = 360.0 / ((chambers.max(1) * events_per_rotor) as f32);
        let mut active = 0;
        for rotor in 0..chambers { for event in 0..events_per_rotor {
            let phase = (rotor * events_per_rotor + event) as f32 * angle_per;
            let mut diff = (current_angle_deg - phase) % 360.0; if diff < 0.0 { diff += 360.0; }
            if diff > 30.0 && diff < 150.0 { active += 1; }
        }}
        active
    }
}
