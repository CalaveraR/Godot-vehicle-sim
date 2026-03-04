use tire_core::{
    tire_contact_aggregation::aggregate_numeric_patch, tire_core::step_wheel, tire_core_reference,
    tire_forces::TireForces, TireCoreConventions, TireCoreMirrorConfig, TireSampleMirror, Vec2,
    Vec3,
};

#[test]
fn numeric_aggregation_is_in_rust_core_scope() {
    let samples = vec![
        TireSampleMirror {
            valid: true,
            penetration: 0.02,
            confidence: 1.0,
            contact_pos_local: Vec3 {
                x: 0.1,
                y: 0.0,
                z: 0.0,
            },
            contact_normal_local: Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            },
            slip_vector: Vec2 { x: 0.1, y: 0.0 },
            ..TireSampleMirror::default()
        },
        TireSampleMirror {
            valid: true,
            penetration: 0.01,
            confidence: 1.0,
            contact_pos_local: Vec3 {
                x: -0.1,
                y: 0.0,
                z: 0.0,
            },
            contact_normal_local: Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            },
            slip_vector: Vec2 { x: -0.1, y: 0.0 },
            ..TireSampleMirror::default()
        },
    ];

    let patch = aggregate_numeric_patch(&samples, TireCoreConventions::default());
    assert!(patch.total_weight > 0.0);
    assert!(patch.avg_normal_local.y > 0.9);
}

#[test]
fn tire_core_reference_functions_remain_pure() {
    let conventions = TireCoreConventions::default();
    let normalized = tire_core_reference::normalize_weights(&[1.0, 1.0, 2.0], conventions);
    let sum: f32 = normalized.iter().sum();
    assert!((sum - 1.0).abs() < 1.0e-6);
}

#[test]
fn step_wheel_returns_force_contract() {
    let samples = vec![TireSampleMirror {
        valid: true,
        penetration: 0.02,
        confidence: 1.0,
        slip_vector: Vec2 { x: 0.02, y: 0.01 },
        contact_pos_ws: Vec3 {
            x: 0.0,
            y: 0.0,
            z: 0.0,
        },
        contact_pos_local: Vec3 {
            x: 0.0,
            y: -0.2,
            z: 0.0,
        },
        contact_normal_local: Vec3 {
            x: 0.0,
            y: 1.0,
            z: 0.0,
        },
        ..TireSampleMirror::default()
    }];

    let out: TireForces = step_wheel(
        &samples,
        &[],
        1.0 / 120.0,
        Vec3::default(),
        0.0,
        TireCoreConventions::default(),
        TireCoreMirrorConfig::default(),
    );
    assert!(out.fz >= 0.0);
    assert!((0.0..=1.0).contains(&out.contact_confidence));
}
