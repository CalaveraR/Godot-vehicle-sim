#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

use crate::TireCoreConventions;

#[derive(Debug, Clone, PartialEq)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct SimCalibration {
    pub version: String,
    pub core: TireCoreConventions,
    pub slew_per_second: f32,
    pub energy_clamp_per_tick: f32,
    pub confidence_threshold: f32,
}

impl Default for SimCalibration {
    fn default() -> Self {
        Self {
            version: "sim_calibration_v1".to_string(),
            core: TireCoreConventions::default(),
            slew_per_second: 50000.0,
            energy_clamp_per_tick: 8000.0,
            confidence_threshold: 0.1,
        }
    }
}

#[cfg(feature = "serde")]
pub fn parse_calibration_json(payload: &str) -> Result<SimCalibration, serde_json::Error> {
    serde_json::from_str(payload)
}
