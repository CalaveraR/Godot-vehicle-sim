use super::SuspensionCoreContracts::{ClampFlags, EffectiveRadiusInput, EffectiveRadiusOutput, Vec3f};

pub fn compute_deformation_clamped(
    deformation: Vec3f,
    tire_induced_deformation: Vec3f,
) -> (Vec3f, ClampFlags) {
    let mut out = Vec3f {
        x: deformation.x + tire_induced_deformation.x,
        y: deformation.y + tire_induced_deformation.y,
        z: deformation.z + tire_induced_deformation.z,
    };

    let pre = out;
    out.x = out.x.clamp(-0.1, 0.1);
    out.y = out.y.clamp(-0.2, 0.0);
    out.z = out.z.clamp(-0.1, 0.1);

    (
        out,
        ClampFlags {
            x_clamped: (pre.x - out.x).abs() > 1.0e-6,
            y_clamped: (pre.y - out.y).abs() > 1.0e-6,
            z_clamped: (pre.z - out.z).abs() > 1.0e-6,
            radius_clamped: false,
        },
    )
}

pub fn compute_effective_radius(input: EffectiveRadiusInput) -> EffectiveRadiusOutput {
    let safe_stiffness = input.base_vertical_stiffness.max(1.0e-6);
    let max_deflection = (input.tire_radius * 0.3).max(1.0e-6);

    let stiffness_mul = if input.vertical_stiffness_mul > 0.0 {
        input.vertical_stiffness_mul
    } else {
        1.0
    };

    let deflection = input.total_load.max(0.0) / (safe_stiffness * stiffness_mul);
    let mut base_radius = input.tire_radius - deflection;
    base_radius *= if input.dynamic_radius_mul > 0.0 {
        input.dynamic_radius_mul
    } else {
        1.0
    };

    let min_r = input.min_effective_radius;
    let max_r = input.tire_radius * 1.2;
    let effective_radius = base_radius.clamp(min_r, max_r);

    EffectiveRadiusOutput {
        effective_radius,
        deflection: deflection.clamp(0.0, max_deflection),
        flags: ClampFlags {
            radius_clamped: (base_radius - effective_radius).abs() > 1.0e-6,
            ..ClampFlags::default()
        },
    }
}

pub fn compute_relaxation_factor(default_value: f32, curve_evaluated_value: Option<f32>) -> f32 {
    curve_evaluated_value.unwrap_or(default_value)
}

pub fn compute_lateral_deformation(curve_evaluated_value: Option<f32>) -> f32 {
    curve_evaluated_value.unwrap_or(0.0)
}
