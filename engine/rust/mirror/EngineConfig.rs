use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/EngineConfig.gd", class_name: "EngineConfig" };

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EngineType { Piston4t, Piston2t, Wankel, Diesel }

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FuelType { Gasoline, Diesel, Ethanol, Flex, Other }

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EngineConfigState {
    pub engine_type: EngineType,
    pub fuel_type: FuelType,
    pub displacement_l: f32,
    pub chambers: u32,
    pub compression_ratio: f32,
    pub idle_rpm: f32,
    pub redline_rpm: f32,
    pub max_rpm: f32,
    pub ambient_temp_c: f32,
    pub atmospheric_pressure_bar: f32,
    pub max_hp: f32,
    pub peak_torque_rpm: f32,
}

impl Default for EngineConfigState {
    fn default() -> Self {
        Self { engine_type: EngineType::Piston4t, fuel_type: FuelType::Gasoline, displacement_l: 2.0, chambers: 4, compression_ratio: 10.0, idle_rpm: 800.0, redline_rpm: 7000.0, max_rpm: 7500.0, ambient_temp_c: 25.0, atmospheric_pressure_bar: 1.01325, max_hp: 150.0, peak_torque_rpm: 4000.0 }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EngineConfigMirror;
impl EngineConfigMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn configure_engine(&self, mut s: EngineConfigState, t: EngineType, chambers: u32, displacement_l: f32) -> EngineConfigState {
        s.engine_type = t; s.chambers = chambers; s.displacement_l = displacement_l;
        match t {
            EngineType::Piston2t => { s.compression_ratio = 9.0; s.idle_rpm = 1000.0; s.redline_rpm = 9000.0; s.max_rpm = 9500.0; }
            EngineType::Wankel => { s.compression_ratio = 9.5; s.displacement_l = chambers as f32 * 0.65 * 2.0; s.idle_rpm = 900.0; s.redline_rpm = 8500.0; s.max_rpm = 9000.0; }
            EngineType::Diesel => { s.compression_ratio = 18.0; s.idle_rpm = 700.0; s.redline_rpm = 5000.0; s.max_rpm = 5500.0; }
            EngineType::Piston4t => { s.compression_ratio = 10.5; s.idle_rpm = 800.0; s.redline_rpm = 7000.0; s.max_rpm = 7500.0; }
        }
        s
    }
    pub fn get_rpm_normalized(&self, s: &EngineConfigState, rpm: f32) -> f32 {
        ((rpm - s.idle_rpm) / (s.redline_rpm - s.idle_rpm)).clamp(0.0, 1.2)
    }
}
