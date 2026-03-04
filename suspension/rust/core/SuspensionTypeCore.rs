//! Canonical parity-facing name aligned with `suspension/godot/core/SuspensionTypeCore.gd`.
//! Implementation delegates to `SuspensionTypeKernels.rs`.

pub use super::SuspensionTypeKernels::TypeGeometryOutput;

pub fn mcperson_geometry_from_eval(
    bump_steer_eval: f32,
    camber_compression_eval: f32,
) -> TypeGeometryOutput {
    super::SuspensionTypeKernels::mcperson_geometry_from_eval(bump_steer_eval, camber_compression_eval)
}

pub fn double_wishbone_geometry(total_load: f32, wishbone_angle: f32) -> TypeGeometryOutput {
    super::SuspensionTypeKernels::double_wishbone_geometry(total_load, wishbone_angle)
}

pub fn multilink_geometry(total_load: f32, link_count: usize) -> TypeGeometryOutput {
    super::SuspensionTypeKernels::multilink_geometry(total_load, link_count)
}

pub fn pushrod_geometry(total_load: f32, rocker_ratio: f32, base_vertical_stiffness: f32) -> TypeGeometryOutput {
    super::SuspensionTypeKernels::pushrod_geometry(total_load, rocker_ratio, base_vertical_stiffness)
}

pub fn pullrod_geometry(total_load: f32, rocker_ratio: f32, base_vertical_stiffness: f32) -> TypeGeometryOutput {
    super::SuspensionTypeKernels::pullrod_geometry(total_load, rocker_ratio, base_vertical_stiffness)
}

pub fn air_suspension_geometry(
    total_load: f32,
    air_volume_liters: f32,
    min_air_pressure: f32,
    max_air_pressure: f32,
) -> TypeGeometryOutput {
    super::SuspensionTypeKernels::air_suspension_geometry(total_load, air_volume_liters, min_air_pressure, max_air_pressure)
}
