#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

impl Vec3 {
    #[inline]
    pub fn new(x: f32, y: f32, z: f32) -> Self {
        Self { x, y, z }
    }

    #[inline]
    pub fn add(self, rhs: Self) -> Self {
        Self::new(self.x + rhs.x, self.y + rhs.y, self.z + rhs.z)
    }

    #[inline]
    pub fn sub(self, rhs: Self) -> Self {
        Self::new(self.x - rhs.x, self.y - rhs.y, self.z - rhs.z)
    }

    #[inline]
    pub fn mul(self, k: f32) -> Self {
        Self::new(self.x * k, self.y * k, self.z * k)
    }

    #[inline]
    pub fn cross(self, rhs: Self) -> Self {
        Self::new(
            self.y * rhs.z - self.z * rhs.y,
            self.z * rhs.x - self.x * rhs.z,
            self.x * rhs.y - self.y * rhs.x,
        )
    }

    #[inline]
    pub fn length(self) -> f32 {
        (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ContactAggregate {
    pub total_force: Vec3,
    pub total_torque: Vec3,
    pub average_position: Vec3,
    pub contact_area: f32,
    pub max_pressure: f32,
    pub weighted_grip: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct WearStepInput {
    pub wheel_slip_ratio: f32,
    pub wheel_slip_angle: f32,
    pub max_pressure: f32,
    pub total_force_magnitude: f32,
    pub current_tire_wear: f32,
    pub base_wear_rate: f32,
    pub base_heat_generation: f32,
    pub cooling_rate: f32,
    pub ambient_temperature: f32,
    pub surface_temperature: f32,
    pub core_temperature: f32,
    pub delta: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct WearStepOutput {
    pub tire_wear: f32,
    pub surface_temperature: f32,
    pub core_temperature: f32,
}

/// Agrega um patch discreto de contato mantendo saída determinística e flat.
///
/// Segurança FFI:
/// - Se qualquer ponteiro for nulo ou `count == 0`, devolve estrutura zerada.
/// - Arrays devem ter ao menos `count` elementos válidos.
#[no_mangle]
pub extern "C" fn tire_aggregate_contacts(
    points_ptr: *const Vec3,
    normals_ptr: *const Vec3,
    forces_ptr: *const f32,
    grips_ptr: *const f32,
    count: usize,
    global_origin: Vec3,
    stiffness: f32,
) -> ContactAggregate {
    if points_ptr.is_null()
        || normals_ptr.is_null()
        || forces_ptr.is_null()
        || grips_ptr.is_null()
        || count == 0
    {
        return ContactAggregate::default();
    }

    let points = unsafe { std::slice::from_raw_parts(points_ptr, count) };
    let normals = unsafe { std::slice::from_raw_parts(normals_ptr, count) };
    let forces = unsafe { std::slice::from_raw_parts(forces_ptr, count) };
    let grips = unsafe { std::slice::from_raw_parts(grips_ptr, count) };

    let mut total_force = Vec3::default();
    let mut total_torque = Vec3::default();
    let mut average_position = Vec3::default();
    let mut contact_area = 0.0_f32;
    let mut max_pressure = 0.0_f32;

    let s = stiffness.max(1.0);

    for i in 0..count {
        let force_dir = normals[i].mul(forces[i]);
        let grip_force = Vec3::new(force_dir.x * grips[i], force_dir.y, force_dir.z * grips[i]);

        total_force = total_force.add(grip_force);
        average_position = average_position.add(points[i]);
        contact_area += forces[i] / s;
        max_pressure = max_pressure.max(forces[i]);
    }

    average_position = average_position.mul(1.0 / count as f32);

    for i in 0..count {
        let lever_arm = points[i].sub(global_origin);
        let force_dir = normals[i].mul(forces[i] * grips[i]);
        total_torque = total_torque.add(lever_arm.cross(force_dir));
    }

    let force_magnitude = total_force.length();
    let mut weighted_grip = 1.0;

    if force_magnitude > 0.0 {
        weighted_grip = 0.0;
        for i in 0..count {
            weighted_grip += grips[i] * (forces[i] / force_magnitude);
        }
    }

    ContactAggregate {
        total_force,
        total_torque,
        average_position,
        contact_area,
        max_pressure,
        weighted_grip,
    }
}

/// Atualiza desgaste e temperatura com step explícito e sem dependência de estado global.
#[no_mangle]
pub extern "C" fn tire_step_wear_and_temperature(input: WearStepInput) -> WearStepOutput {
    let slip = input.wheel_slip_ratio;
    let slip_angle = input.wheel_slip_angle.abs();

    let mut wear_rate = input.base_wear_rate;
    wear_rate *= 1.0 + (slip * 5.0) + (slip_angle * 3.0);
    wear_rate *= input.max_pressure / 10_000.0;

    let mut tire_wear = (input.current_tire_wear + wear_rate * input.delta).clamp(0.0, 1.0);

    let mut heat_generation = input.base_heat_generation;
    heat_generation *= 1.0 + (slip * 3.0) + (slip_angle * 2.0);
    heat_generation *= input.total_force_magnitude / 10_000.0;

    let surface_heat = heat_generation * 0.7;
    let core_heat = heat_generation * 0.3;

    let mut surface_temperature = input.surface_temperature + surface_heat * input.delta;
    let mut core_temperature = input.core_temperature + core_heat * input.delta;

    let cooling = input.cooling_rate * (input.ambient_temperature - surface_temperature);
    surface_temperature += cooling * input.delta;
    core_temperature += (cooling * 0.5) * input.delta;

    if !tire_wear.is_finite() {
        tire_wear = 0.0;
    }

    WearStepOutput {
        tire_wear,
        surface_temperature,
        core_temperature,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn aggregate_returns_data_for_basic_inputs() {
        let points = [Vec3::new(0.0, -0.2, 0.0), Vec3::new(0.1, -0.2, 0.0)];
        let normals = [Vec3::new(0.0, 1.0, 0.0), Vec3::new(0.0, 1.0, 0.0)];
        let forces = [2000.0, 1800.0];
        let grips = [1.0, 0.9];

        let out = tire_aggregate_contacts(
            points.as_ptr(),
            normals.as_ptr(),
            forces.as_ptr(),
            grips.as_ptr(),
            points.len(),
            Vec3::default(),
            15_000.0,
        );

        assert!(out.total_force.y > 0.0);
        assert!(out.contact_area > 0.0);
        assert!(out.max_pressure >= 2000.0);
    }

    #[test]
    fn wear_step_is_deterministic_for_same_input() {
        let input = WearStepInput {
            wheel_slip_ratio: 0.12,
            wheel_slip_angle: 0.08,
            max_pressure: 3200.0,
            total_force_magnitude: 4100.0,
            current_tire_wear: 0.2,
            base_wear_rate: 0.001,
            base_heat_generation: 0.15,
            cooling_rate: 0.02,
            ambient_temperature: 22.0,
            surface_temperature: 65.0,
            core_temperature: 58.0,
            delta: 1.0 / 60.0,
        };

        let a = tire_step_wear_and_temperature(input);
        let b = tire_step_wear_and_temperature(input);

        assert_eq!(a, b);
    }
}
