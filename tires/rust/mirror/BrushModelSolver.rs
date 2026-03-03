use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/BrushModelSolver.gd", class_name: "BrushModelSolver" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct BrushModelSolverState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct BrushModelSolverMirror;

impl BrushModelSolverMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &BrushModelSolverState, _dt: f32) -> BrushModelSolverState { input.clone() }
    pub fn solve(&self, input: &BrushModelSolverState) -> BrushModelSolverState { input.clone() }
    pub fn get_last_forces(&self, input: &BrushModelSolverState) -> BrushModelSolverState { input.clone() }
}
