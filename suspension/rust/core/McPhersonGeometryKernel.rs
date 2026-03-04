use super::SuspensionCoreContracts::Vec3f;

#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct McPhersonGeometryOutput {
    pub toe_delta: f32,
    pub camber_delta: f32,
    pub roll_center: Vec3f,
    pub instant_center: Vec3f,
}

/// Pure numeric outputs for McPherson-specific geometry.
/// Curve interpolation itself stays in Godot (or pre-baked LUT passed here).
pub fn compute_geometry_deltas_mcperson(
    deformation_y: f32,
    tire_radius: f32,
    bump_steer_eval: f32,
    camber_compression_eval: f32,
) -> McPhersonGeometryOutput {
    McPhersonGeometryOutput {
        toe_delta: bump_steer_eval,
        camber_delta: camber_compression_eval,
        roll_center: Vec3f {
            x: 0.0,
            y: tire_radius - deformation_y * 0.7,
            z: 0.0,
        },
        instant_center: Vec3f {
            x: 0.0,
            y: tire_radius * 0.5,
            z: -tire_radius,
        },
    }
}
