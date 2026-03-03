use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/diesel_combustion.gd", class_name: "DieselCombustionSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct DieselCombustionSystemMirror;
impl DieselCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    fn injection_angle(rpm_n: f32) -> f32 { if rpm_n <= 0.5 { 20.0 + (rpm_n/0.5)*(15.0-20.0) } else { 15.0 + ((rpm_n-0.5)/0.5)*(10.0-15.0) } }
    pub fn update_combustion_events(&self, chambers: u32, current_angle_deg: f32, rpm_n: f32) -> u32 {
        let angle_per = 720.0 / (chambers.max(1) as f32);
        let inj = Self::injection_angle(rpm_n.clamp(0.0,1.0));
        (0..chambers).filter(|i| {
            let phase = *i as f32 * angle_per;
            let mut diff = (current_angle_deg - phase) % 720.0; if diff < 0.0 { diff += 720.0; }
            diff > (360.0 - inj) || diff < 10.0
        }).count() as u32
    }
}
