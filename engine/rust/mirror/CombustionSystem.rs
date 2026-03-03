use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/CombustionSystem.gd", class_name: "CombustionSystem" };

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CombustionInput {
    pub afr: f32,
    pub ignition_quality: f32,
    pub throttle: f32,
    pub load: f32,
    pub oil_temp_c: f32,
    pub air_mass_per_cycle: f32,
    pub fuel_mass_per_cycle: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CombustionSystemState {
    pub output_rpm: f32,
    pub combustion_efficiency: f32,
    pub residual_gas_fraction: f32,
    pub average_combustion_temp: f32,
    pub peak_combustion_temp: f32,
}
impl Default for CombustionSystemState {
    fn default() -> Self { Self { output_rpm: 0.0, combustion_efficiency: 0.85, residual_gas_fraction: 0.15, average_combustion_temp: 800.0, peak_combustion_temp: 1200.0 } }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct CombustionSystemMirror;
impl CombustionSystemMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    fn approx_curve(x: f32, pts: &[(f32,f32)]) -> f32 {
        if x <= pts[0].0 { return pts[0].1; }
        for w in pts.windows(2) { let (x0,y0)=w[0]; let (x1,y1)=w[1]; if x<=x1 { let t=(x-x0)/(x1-x0).max(1e-6); return y0 + (y1-y0)*t; }}
        pts[pts.len()-1].1
    }
    pub fn calculate_combustion_efficiency(&self, mut s: CombustionSystemState, i: CombustionInput) -> CombustionSystemState {
        let afr_deviation = ((i.afr - 14.7).abs() / 14.7).max(0.0);
        let eff = (0.95 - afr_deviation * 0.5) * i.ignition_quality * (1.0 - s.residual_gas_fraction);
        let temp_factor = Self::approx_curve(s.average_combustion_temp, &[(700.0,0.75),(900.0,0.92),(1100.0,0.85)]);
        let afr_factor = Self::approx_curve(i.afr, &[(12.0,0.85),(14.7,0.98),(16.0,0.90)]);
        s.combustion_efficiency = (eff * temp_factor * afr_factor).clamp(0.3, 0.95);
        s
    }
    pub fn calculate_combustion_torque(&self, s: &CombustionSystemState, i: CombustionInput) -> f32 {
        let energy = i.fuel_mass_per_cycle * 42e6 * s.combustion_efficiency;
        energy * 0.0001 * i.throttle
    }
    pub fn calculate_combustion_temperature(&self, mut s: CombustionSystemState, i: CombustionInput) -> CombustionSystemState {
        s.peak_combustion_temp = 900.0 + i.load * 500.0;
        s.average_combustion_temp = 700.0 + i.load * 300.0;
        if i.afr > 14.7 { s.average_combustion_temp += (i.afr - 14.7) * 50.0; } else { s.average_combustion_temp -= (14.7 - i.afr) * 30.0; }
        let oil_temp_factor = (i.oil_temp_c / 120.0).clamp(0.8,1.2);
        s.peak_combustion_temp *= oil_temp_factor;
        s.average_combustion_temp *= oil_temp_factor;
        s
    }
}
