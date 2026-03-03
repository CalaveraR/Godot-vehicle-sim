use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize, Default)]
pub struct TypeGeometryOutput {
    pub dynamic_camber_delta: f32,
    pub dynamic_toe_delta: f32,
    pub deformation_y_delta: f32,
    pub aux_value: f32,
}

pub fn mcperson_geometry_from_eval(
    bump_steer_eval: f32,
    camber_compression_eval: f32,
) -> TypeGeometryOutput {
    TypeGeometryOutput {
        dynamic_camber_delta: camber_compression_eval,
        dynamic_toe_delta: bump_steer_eval,
        ..TypeGeometryOutput::default()
    }
}

pub fn double_wishbone_geometry(total_load: f32, wishbone_angle: f32) -> TypeGeometryOutput {
    TypeGeometryOutput {
        dynamic_camber_delta: wishbone_angle + total_load * 0.00005,
        dynamic_toe_delta: total_load * 0.00001,
        ..TypeGeometryOutput::default()
    }
}

pub fn multilink_geometry(total_load: f32, link_count: usize) -> TypeGeometryOutput {
    let count = link_count.max(1);
    let load_per_link = total_load / count as f32;
    let mut link_forces = vec![0.0_f32; count];
    for (i, f) in link_forces.iter_mut().enumerate() {
        *f = load_per_link * (1.0 + (i as f32 * 0.5).sin());
    }

    let l0 = *link_forces.first().unwrap_or(&0.0);
    let l1 = *link_forces.get(1).unwrap_or(&0.0);
    let l2 = *link_forces.get(2).unwrap_or(&0.0);

    TypeGeometryOutput {
        dynamic_camber_delta: l0 * 0.00001,
        dynamic_toe_delta: (l1 - l2) * 0.00002,
        ..TypeGeometryOutput::default()
    }
}

pub fn pushrod_geometry(total_load: f32, rocker_ratio: f32, base_vertical_stiffness: f32) -> TypeGeometryOutput {
    let spring_force = total_load * rocker_ratio;
    let deformation_y = spring_force / base_vertical_stiffness.max(1.0e-6);
    let pushrod_angle = 0.3 + deformation_y * 0.1;
    TypeGeometryOutput {
        deformation_y_delta: deformation_y,
        aux_value: pushrod_angle,
        ..TypeGeometryOutput::default()
    }
}

pub fn pullrod_geometry(total_load: f32, rocker_ratio: f32, base_vertical_stiffness: f32) -> TypeGeometryOutput {
    let spring_force = total_load * rocker_ratio;
    let deformation_y = spring_force / base_vertical_stiffness.max(1.0e-6);
    let pullrod_angle = -0.2 - deformation_y * 0.1;
    TypeGeometryOutput {
        deformation_y_delta: deformation_y,
        aux_value: pullrod_angle,
        ..TypeGeometryOutput::default()
    }
}

pub fn air_suspension_geometry(
    total_load: f32,
    air_volume_liters: f32,
    min_air_pressure: f32,
    max_air_pressure: f32,
) -> TypeGeometryOutput {
    let new_pressure = total_load / (air_volume_liters.max(1.0e-6) * 0.001) + min_air_pressure;
    let pressure = new_pressure.clamp(min_air_pressure, max_air_pressure);
    let stiffness = pressure * 300.0;
    TypeGeometryOutput {
        aux_value: pressure,
        deformation_y_delta: stiffness,
        ..TypeGeometryOutput::default()
    }
}
