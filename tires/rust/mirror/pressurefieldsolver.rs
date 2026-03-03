use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/pressurefieldsolver.gd", class_name: "PressureFieldSolver" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PressureFieldSolverState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct PressureFieldSolverMirror;

impl PressureFieldSolverMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &PressureFieldSolverState, _dt: f32) -> PressureFieldSolverState { input.clone() }
    pub fn solve(&self, input: &PressureFieldSolverState) -> PressureFieldSolverState { input.clone() }
    pub fn solve_patch_data(&self, input: &PressureFieldSolverState) -> PressureFieldSolverState { input.clone() }
}
