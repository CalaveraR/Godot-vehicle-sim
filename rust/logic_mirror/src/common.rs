use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Default, PartialEq, Serialize, Deserialize)]
pub struct Vec2 { pub x: f32, pub y: f32 }

#[derive(Debug, Clone, Copy, Default, PartialEq, Serialize, Deserialize)]
pub struct Vec3 { pub x: f32, pub y: f32, pub z: f32 }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct MirrorMeta {
    pub source_gd: &'static str,
    pub class_name: &'static str,
}
