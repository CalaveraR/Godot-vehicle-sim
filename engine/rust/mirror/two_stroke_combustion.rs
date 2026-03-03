use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/two_stroke_combustion.gd", class_name: "TwoStrokeCombustionSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct TwoStrokeCombustionSystemMirror;
impl TwoStrokeCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update_combustion_events(&self, chambers: u32, current_angle_deg: f32) -> u32 {
        let angle_per = 360.0 / (chambers.max(1) as f32);
        (0..chambers).filter(|i| {
            let phase = *i as f32 * angle_per;
            let mut diff = (current_angle_deg - phase) % 360.0; if diff < 0.0 { diff += 360.0; }
            diff < 30.0 || diff > 330.0
        }).count() as u32
    }
}
