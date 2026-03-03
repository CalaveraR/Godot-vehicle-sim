use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/four_stroke_combustion.gd", class_name: "FourStrokeCombustionSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct FourStrokeCombustionSystemMirror;
impl FourStrokeCombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update_combustion_events(&self, chambers: u32, current_angle_deg: f32) -> u32 {
        let angle_per = 720.0 / (chambers.max(1) as f32);
        (0..chambers).filter(|i| {
            let phase = *i as f32 * angle_per;
            let mut diff = (current_angle_deg - phase) % 720.0; if diff < 0.0 { diff += 720.0; }
            diff < 30.0 || diff > 690.0
        }).count() as u32
    }
}
