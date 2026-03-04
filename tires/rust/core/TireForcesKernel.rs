#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

use crate::Vec3;

/// Rust mirror of `tires/godot/core/TireForces.gd`.
#[derive(Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TireForces {
    pub fx: f32,
    pub fy: f32,
    pub fz: f32,
    pub mz: f32,
    pub center_of_pressure_ws: Vec3,
    pub contact_confidence: f32,
}
