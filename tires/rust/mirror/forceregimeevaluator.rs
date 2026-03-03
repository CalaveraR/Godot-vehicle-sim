use serde::{Deserialize, Serialize};
use crate::common::{MirrorMeta, Vec2, Vec3};

pub const META: MirrorMeta = MirrorMeta { source_gd: "tires/godot/forceregimeevaluator.gd", class_name: "ForceRegimeEvaluator" };

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ForceRegimeEvaluatorState {
    pub scalar_state: f32,
    pub v2_state: Vec2,
    pub v3_state: Vec3,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ForceRegimeEvaluatorMirror;

impl ForceRegimeEvaluatorMirror {
    pub fn meta(&self) -> MirrorMeta { META.clone() }
    pub fn step(&self, input: &ForceRegimeEvaluatorState, _dt: f32) -> ForceRegimeEvaluatorState { input.clone() }
    pub fn configure(&self, input: &ForceRegimeEvaluatorState) -> ForceRegimeEvaluatorState { input.clone() }
    pub fn evaluate(&self, input: &ForceRegimeEvaluatorState) -> ForceRegimeEvaluatorState { input.clone() }
    pub fn get_slip_history(&self, input: &ForceRegimeEvaluatorState) -> ForceRegimeEvaluatorState { input.clone() }
    pub fn get_transition_count(&self, input: &ForceRegimeEvaluatorState) -> ForceRegimeEvaluatorState { input.clone() }
    pub fn reset_history(&self, input: &ForceRegimeEvaluatorState) -> ForceRegimeEvaluatorState { input.clone() }
}
