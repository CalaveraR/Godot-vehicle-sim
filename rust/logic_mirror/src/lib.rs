//! [CORE_RS] Auto-generated redundancy layer for logical GDScript classes.
pub mod common;
pub mod engine_rust_mirror_combustionsystem;
pub mod engine_rust_mirror_engineconfig;
pub mod engine_rust_mirror_enginephysics;
pub mod engine_rust_mirror_inductionsystem;
pub mod engine_rust_mirror_turbosystem;
pub mod engine_rust_mirror_anti_lag_system;
pub mod engine_rust_mirror_compound_turbo_system;
pub mod engine_rust_mirror_diesel_combustion;
pub mod engine_rust_mirror_four_stroke_combustion;
pub mod engine_rust_mirror_naturally_aspirated_system;
pub mod engine_rust_mirror_single_turbo_system;
pub mod engine_rust_mirror_staggered_turbo_system;
pub mod engine_rust_mirror_supercharger_system;
pub mod engine_rust_mirror_twin_charged_system;
pub mod engine_rust_mirror_twin_turbo_system;
pub mod engine_rust_mirror_two_stroke_combustion;
pub mod engine_rust_mirror_wankel_combustion;
pub mod suspension_rust_mirror_airsuspension;
pub mod suspension_rust_mirror_doublewishbonesuspension;
pub mod suspension_rust_mirror_mcphersonsuspension;
pub mod suspension_rust_mirror_multilinksuspension;
pub mod suspension_rust_mirror_pullrodsuspension;
pub mod suspension_rust_mirror_pushrodsuspension;
pub mod suspension_rust_mirror_solidaxlesuspension;
pub mod suspension_rust_mirror_tiresuspensionbridge;
pub mod tires_rust_mirror_brushmodelsolver;
pub mod tires_rust_mirror_contactconfidencemodel;
pub mod tires_rust_mirror_contactpatch;
pub mod tires_rust_mirror_neutralinfluencecontract;
pub mod tires_rust_mirror_temporalhistory;
pub mod tires_rust_mirror_tirecontactsolverpipeline;
pub mod tires_rust_mirror_tirecorereference;
pub mod tires_rust_mirror_tireprofilemeshbuilder;
pub mod tires_rust_mirror_tirerigidbodyapplicator;
pub mod tires_rust_mirror_aggregation_tirecontactaggregation;
pub mod tires_rust_mirror_applyinfluencetoshaderstate;
pub mod tires_rust_mirror_bridge_tireinputbridge;
pub mod tires_rust_mirror_bridge_tireoutputbridge;
pub mod tires_rust_mirror_contactpatchbuilder;
pub mod tires_rust_mirror_contactpatchstate;
pub mod tires_rust_mirror_core_contactpatchdata;
pub mod tires_rust_mirror_core_tirecore;
pub mod tires_rust_mirror_core_tireforces;
pub mod tires_rust_mirror_data_wheelstate;
pub mod tires_rust_mirror_data_tiresample;
pub mod tires_rust_mirror_forceregimeevaluator;
pub mod tires_rust_mirror_geometryengine;
pub mod tires_rust_mirror_influencecontractbuilder;
pub mod tires_rust_mirror_pressurefieldsolver;
pub mod tires_rust_mirror_runtime_tirecontactruntime;
pub mod tires_rust_mirror_surface_tiresurfaceresponsemodel;

#[derive(Debug, Clone, Copy)]
pub struct MirrorRegistration { pub module: &'static str, pub source_gd: &'static str, pub class_name: &'static str }

pub const REGISTRY: &[MirrorRegistration] = &[
    MirrorRegistration { module: "engine_rust_mirror_combustionsystem", source_gd: "engine/godot/CombustionSystem.gd", class_name: "CombustionSystem" },
    MirrorRegistration { module: "engine_rust_mirror_engineconfig", source_gd: "engine/godot/EngineConfig.gd", class_name: "EngineConfig" },
    MirrorRegistration { module: "engine_rust_mirror_enginephysics", source_gd: "engine/godot/EnginePhysics.gd", class_name: "EnginePhysics" },
    MirrorRegistration { module: "engine_rust_mirror_inductionsystem", source_gd: "engine/godot/InductionSystem.gd", class_name: "InductionSystem" },
    MirrorRegistration { module: "engine_rust_mirror_turbosystem", source_gd: "engine/godot/TurboSystem.gd", class_name: "TurboSystem" },
    MirrorRegistration { module: "engine_rust_mirror_anti_lag_system", source_gd: "engine/godot/anti_lag_system.gd", class_name: "AntiLagSystem" },
    MirrorRegistration { module: "engine_rust_mirror_compound_turbo_system", source_gd: "engine/godot/compound_turbo_system.gd", class_name: "CompoundTurboSystem" },
    MirrorRegistration { module: "engine_rust_mirror_diesel_combustion", source_gd: "engine/godot/diesel_combustion.gd", class_name: "DieselCombustionSystem" },
    MirrorRegistration { module: "engine_rust_mirror_four_stroke_combustion", source_gd: "engine/godot/four_stroke_combustion.gd", class_name: "FourStrokeCombustionSystem" },
    MirrorRegistration { module: "engine_rust_mirror_naturally_aspirated_system", source_gd: "engine/godot/naturally_aspirated_system.gd", class_name: "NaturallyAspiratedSystem" },
    MirrorRegistration { module: "engine_rust_mirror_single_turbo_system", source_gd: "engine/godot/single_turbo_system.gd", class_name: "SingleTurboSystem" },
    MirrorRegistration { module: "engine_rust_mirror_staggered_turbo_system", source_gd: "engine/godot/staggered_turbo_system.gd", class_name: "StaggeredTurboSystem" },
    MirrorRegistration { module: "engine_rust_mirror_supercharger_system", source_gd: "engine/godot/supercharger_system.gd", class_name: "SuperchargerSystem" },
    MirrorRegistration { module: "engine_rust_mirror_twin_charged_system", source_gd: "engine/godot/twin_charged_system.gd", class_name: "TwinChargedSystem" },
    MirrorRegistration { module: "engine_rust_mirror_twin_turbo_system", source_gd: "engine/godot/twin_turbo_system.gd", class_name: "TwinTurboSystem" },
    MirrorRegistration { module: "engine_rust_mirror_two_stroke_combustion", source_gd: "engine/godot/two_stroke_combustion.gd", class_name: "TwoStrokeCombustionSystem" },
    MirrorRegistration { module: "engine_rust_mirror_wankel_combustion", source_gd: "engine/godot/wankel_combustion.gd", class_name: "WankelCombustionSystem" },
    MirrorRegistration { module: "suspension_rust_mirror_airsuspension", source_gd: "suspension/godot/AirSuspension.gd", class_name: "AirSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_doublewishbonesuspension", source_gd: "suspension/godot/DoubleWishboneSuspension.gd", class_name: "DoubleWishboneSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_mcphersonsuspension", source_gd: "suspension/godot/McPhersonSuspension.gd", class_name: "McPhersonSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_multilinksuspension", source_gd: "suspension/godot/MultiLinkSuspension.gd", class_name: "MultiLinkSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_pullrodsuspension", source_gd: "suspension/godot/PullRodSuspension.gd", class_name: "PullRodSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_pushrodsuspension", source_gd: "suspension/godot/PushRodSuspension.gd", class_name: "PushRodSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_solidaxlesuspension", source_gd: "suspension/godot/SolidAxleSuspension.gd", class_name: "SolidAxleSuspension" },
    MirrorRegistration { module: "suspension_rust_mirror_tiresuspensionbridge", source_gd: "suspension/godot/TireSuspensionBridge.gd", class_name: "TireSuspensionBridge" },
    MirrorRegistration { module: "tires_rust_mirror_brushmodelsolver", source_gd: "tires/godot/BrushModelSolver.gd", class_name: "BrushModelSolver" },
    MirrorRegistration { module: "tires_rust_mirror_contactconfidencemodel", source_gd: "tires/godot/ContactConfidenceModel.gd", class_name: "ContactConfidenceModel" },
    MirrorRegistration { module: "tires_rust_mirror_contactpatch", source_gd: "tires/godot/ContactPatch.gd", class_name: "ContactPatch" },
    MirrorRegistration { module: "tires_rust_mirror_neutralinfluencecontract", source_gd: "tires/godot/NeutralInfluenceContract.gd", class_name: "NeutralInfluenceContract" },
    MirrorRegistration { module: "tires_rust_mirror_temporalhistory", source_gd: "tires/godot/TemporalHistory.gd", class_name: "TemporalHistory" },
    MirrorRegistration { module: "tires_rust_mirror_tirecontactsolverpipeline", source_gd: "tires/godot/TireContactSolverpipeline.gd", class_name: "TireContactSolver" },
    MirrorRegistration { module: "tires_rust_mirror_tirecorereference", source_gd: "tires/godot/TireCoreReference.gd", class_name: "TireCoreReference" },
    MirrorRegistration { module: "tires_rust_mirror_tireprofilemeshbuilder", source_gd: "tires/godot/TireProfileMeshBuilder.gd", class_name: "TireProfileMeshBuilder" },
    MirrorRegistration { module: "tires_rust_mirror_tirerigidbodyapplicator", source_gd: "tires/godot/TireRigidBodyApplicator.gd", class_name: "TireRigidBodyApplicator" },
    MirrorRegistration { module: "tires_rust_mirror_aggregation_tirecontactaggregation", source_gd: "tires/godot/aggregation/TireContactAggregation.gd", class_name: "TireContactAggregation" },
    MirrorRegistration { module: "tires_rust_mirror_applyinfluencetoshaderstate", source_gd: "tires/godot/applyinfluencetoshaderstate.gd", class_name: "ApplyInfluenceToShaderState" },
    MirrorRegistration { module: "tires_rust_mirror_bridge_tireinputbridge", source_gd: "tires/godot/bridge/TireInputBridge.gd", class_name: "TireInputBridge" },
    MirrorRegistration { module: "tires_rust_mirror_bridge_tireoutputbridge", source_gd: "tires/godot/bridge/TireOutputBridge.gd", class_name: "TireOutputBridge" },
    MirrorRegistration { module: "tires_rust_mirror_contactpatchbuilder", source_gd: "tires/godot/contactpatchbuilder.gd", class_name: "ContactPatchBuilder" },
    MirrorRegistration { module: "tires_rust_mirror_contactpatchstate", source_gd: "tires/godot/contactpatchstate.gd", class_name: "ContactPatchstate" },
    MirrorRegistration { module: "tires_rust_mirror_core_contactpatchdata", source_gd: "tires/godot/core/ContactPatchData.gd", class_name: "ContactPatchData" },
    MirrorRegistration { module: "tires_rust_mirror_core_tirecore", source_gd: "tires/godot/core/TireCore.gd", class_name: "TireCore" },
    MirrorRegistration { module: "tires_rust_mirror_core_tireforces", source_gd: "tires/godot/core/TireForces.gd", class_name: "TireForces" },
    MirrorRegistration { module: "tires_rust_mirror_data_wheelstate", source_gd: "tires/godot/data/WheelState.gd", class_name: "WheelState" },
    MirrorRegistration { module: "tires_rust_mirror_data_tiresample", source_gd: "tires/godot/data/tiresample.gd", class_name: "TireSample" },
    MirrorRegistration { module: "tires_rust_mirror_forceregimeevaluator", source_gd: "tires/godot/forceregimeevaluator.gd", class_name: "ForceRegimeEvaluator" },
    MirrorRegistration { module: "tires_rust_mirror_geometryengine", source_gd: "tires/godot/geometryengine.gd", class_name: "GeometryEngine" },
    MirrorRegistration { module: "tires_rust_mirror_influencecontractbuilder", source_gd: "tires/godot/influencecontractbuilder.gd", class_name: "InfluenceContractBuilder" },
    MirrorRegistration { module: "tires_rust_mirror_pressurefieldsolver", source_gd: "tires/godot/pressurefieldsolver.gd", class_name: "PressureFieldSolver" },
    MirrorRegistration { module: "tires_rust_mirror_runtime_tirecontactruntime", source_gd: "tires/godot/runtime/TireContactRuntime.gd", class_name: "TireContactRuntime" },
    MirrorRegistration { module: "tires_rust_mirror_surface_tiresurfaceresponsemodel", source_gd: "tires/godot/surface/TireSurfaceResponseModel.gd", class_name: "TireSurfaceResponseModel" },
];

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn registry_not_empty() { assert!(!REGISTRY.is_empty()); }
}
