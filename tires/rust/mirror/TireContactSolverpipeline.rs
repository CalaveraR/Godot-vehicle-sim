use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/TireContactSolverpipeline.gd", class_name: "TireContactSolver" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireContactSolverState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TireContactSolverMirror;

impl TireContactSolverMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &TireContactSolverState, _dt: f32) -> TireContactSolverState { input.clone() }
    pub fn initialize(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn solve(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn set_regime_transitions(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn set_force_regime(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn set_effort_metrics(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_current_patch(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_patch_confidence(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_sample_count(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_current_regime(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_regime_statistics(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_effort_metrics(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn get_debug_info(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn reset(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn configure_models(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn set_model_enabled(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn set_debug_options(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
    pub fn export_for_visualization(&self, input: &TireContactSolverState) -> TireContactSolverState { input.clone() }
}
