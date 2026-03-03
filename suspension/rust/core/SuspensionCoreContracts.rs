use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct Vec3f {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct ClampFlags {
    pub x_clamped: bool,
    pub y_clamped: bool,
    pub z_clamped: bool,
    pub radius_clamped: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct EffectiveRadiusInput {
    pub total_load: f32,
    pub base_vertical_stiffness: f32,
    pub tire_radius: f32,
    pub min_effective_radius: f32,
    /// Godot-side evaluated multiplier from vertical stiffness curve.
    pub vertical_stiffness_mul: f32,
    /// Godot-side evaluated multiplier from dynamic radius curve.
    pub dynamic_radius_mul: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct EffectiveRadiusOutput {
    pub effective_radius: f32,
    pub deflection: f32,
    pub flags: ClampFlags,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionCoreState {
    pub deformation: Vec3f,
    pub effective_radius: f32,
    pub relaxation_factor: f32,
    pub lateral_deformation: f32,
    pub dynamic_camber: f32,
    pub dynamic_toe: f32,
}


#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionWheelInput {
    pub wheel_id: u32,
    pub suspension_type: u32,
    pub total_load: f32,
    pub tire_radius: f32,
    pub min_effective_radius: f32,
    pub base_vertical_stiffness: f32,
    pub tire_induced_deformation: Vec3f,
    pub vertical_stiffness_factor: f32,
    pub dynamic_radius_factor: f32,
    pub relaxation_curve_eval: f32,
    pub lateral_deformation_curve_eval: f32,
    pub base_camber_eval: f32,
    pub base_caster_eval: f32,
    pub base_toe_eval: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionWheelOutput {
    pub deformation: Vec3f,
    pub dynamic_camber: f32,
    pub dynamic_caster: f32,
    pub dynamic_toe: f32,
    pub effective_radius: f32,
    pub relaxation_factor: f32,
    pub lateral_deformation: f32,
    pub flags: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionAxleInput {
    pub load_left: f32,
    pub load_right: f32,
    pub axle_stiffness: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct SuspensionAxleOutput {
    pub deformation_y_left: f32,
    pub deformation_y_right: f32,
    pub flags: u32,
}
