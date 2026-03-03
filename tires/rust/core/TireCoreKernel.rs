use crate::{
    contact_patch_data::ContactPatchData, tire_forces::TireForces, TireCoreConventions,
    TireCoreMirrorConfig, TireSampleMirror, Vec2, Vec3,
};

/// Rust mirror of the pure numeric logic from `tires/godot/core/TireCore.gd`.
pub fn step_wheel(
    shader_samples: &[TireSampleMirror],
    raycast_samples: &[TireSampleMirror],
    dt: f32,
    current_velocity_ws: Vec3,
    previous_fz: f32,
    conventions: TireCoreConventions,
    config: TireCoreMirrorConfig,
) -> TireForces {
    let mut merged = Vec::with_capacity(shader_samples.len() + raycast_samples.len());
    merged.extend_from_slice(shader_samples);
    merged.extend_from_slice(raycast_samples);

    let patch = ContactPatchData::from_samples(&merged, conventions);
    let mut out = TireForces {
        contact_confidence: patch.patch_confidence,
        center_of_pressure_ws: patch.center_of_pressure_ws(&merged),
        ..TireForces::default()
    };

    if patch.patch_confidence < config.confidence_min_for_contact && raycast_samples.is_empty() {
        let t = (dt * config.emergency_fz_falloff_rate).clamp(0.0, 1.0);
        out.fz = previous_fz + (0.0 - previous_fz) * t;
        return out;
    }

    let base_k = 120000.0;
    let base_c = 3000.0;
    let pen_rate = if merged.is_empty() {
        0.0
    } else {
        merged.iter().map(|s| s.penetration_velocity).sum::<f32>() / merged.len() as f32
    };

    out.fz = (base_k * patch.penetration_avg + base_c * pen_rate).max(0.0);
    out.fx = -patch.average_slip.x * out.fz * 0.5;
    out.fy = -patch.average_slip.y * out.fz * 0.7;

    let mut tangential = Vec2 {
        x: out.fx,
        y: out.fy,
    };
    let max_tangent = out.fz;
    if tangential.length() > max_tangent && tangential.length() > 0.0 {
        tangential = tangential.normalized();
        out.fx = tangential.x * max_tangent;
        out.fy = tangential.y * max_tangent;
    }

    out.mz = out.fy * patch.center_of_pressure_local.x;

    if dt > 0.0 {
        let f = Vec3 {
            x: out.fx,
            y: out.fz,
            z: out.fy,
        };
        let delta_e = (f.dot(current_velocity_ws) * dt).abs();
        if delta_e > config.energy_delta_limit {
            let scale = config.energy_delta_limit / delta_e.max(1.0e-6);
            out.fx *= scale;
            out.fy *= scale;
            out.fz *= scale;
            out.mz *= scale;
        }
    }

    out
}
