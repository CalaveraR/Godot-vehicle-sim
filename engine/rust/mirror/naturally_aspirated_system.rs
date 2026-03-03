use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;
pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/naturally_aspirated_system.gd", class_name: "NaturallyAspiratedSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct NaturallyAspiratedSystemState { pub current_boost: f32, pub current_efficiency: f32, pub intake_temperature_c: f32 }
impl Default for NaturallyAspiratedSystemState { fn default() -> Self { Self { current_boost:1.0, current_efficiency:1.0, intake_temperature_c:25.0 } } }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct NaturallyAspiratedSystemMirror;
impl NaturallyAspiratedSystemMirror { pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn update(&self, mut s: NaturallyAspiratedSystemState, ambient_temp_c: f32) -> NaturallyAspiratedSystemState { s.current_boost=1.0; s.current_efficiency=1.0; s.intake_temperature_c=ambient_temp_c; s }
}
