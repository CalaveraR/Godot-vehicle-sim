use serde::{Deserialize, Serialize};
use crate::common::MirrorMeta;

pub const META: MirrorMeta = MirrorMeta { source_gd: "engine/godot/EnginePhysics.gd", class_name: "EnginePhysics" };
const HP_TO_TORQUE: f32 = 5252.0;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EnginePhysicsInput {
    pub rpm: f32,
    pub redline_rpm: f32,
    pub throttle: f32,
    pub boost: f32,
    pub induction_efficiency: f32,
    pub volumetric_efficiency: f32,
    pub vvt_advance: f32,
    pub max_vvt_advance: f32,
    pub vibration_level: f32,
    pub cylinder_count: u32,
    pub max_hp: f32,
    pub peak_torque_rpm: f32,
    pub supercharged: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EnginePhysicsOutput { pub torque: f32, pub horsepower: f32 }

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EnginePhysicsMirror;
impl EnginePhysicsMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    fn torque_curve_fraction(rpm_n: f32) -> f32 {
        if rpm_n <= 0.5 { 0.6 + (rpm_n/0.5)*0.4 } else { 1.0 - ((rpm_n-0.5)/0.5)*0.15 }
    }
    pub fn calculate_engine_output(&self, i: EnginePhysicsInput) -> EnginePhysicsOutput {
        let rpm_n = (i.rpm / i.redline_rpm.max(1.0)).clamp(0.0, 1.2);
        let base_torque = Self::torque_curve_fraction(rpm_n) * (i.max_hp * HP_TO_TORQUE) / i.peak_torque_rpm.max(1.0);
        let mut torque = base_torque * i.boost.max(0.0) * i.volumetric_efficiency.max(0.0) * i.induction_efficiency.max(0.0) * i.throttle.clamp(0.0,1.0);
        let vvt_factor = 1.0 + (i.vvt_advance / i.max_vvt_advance.max(1.0)) * 0.1;
        torque *= vvt_factor.clamp(0.9,1.1);
        if i.supercharged {
            let drag = base_torque * 0.15 * (i.boost - 1.0).max(0.0);
            torque = (torque - drag).max(base_torque * 0.7);
        }
        torque *= (1.0 - i.vibration_level * 0.1).clamp(0.8,1.0);
        if i.cylinder_count >= 6 { torque *= 1.05; }
        let hp = ((torque * i.rpm) / HP_TO_TORQUE).min(i.max_hp);
        EnginePhysicsOutput { torque, horsepower: hp }
    }
}
