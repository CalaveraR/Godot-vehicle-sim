#![cfg(feature = "serde")]

use std::fs;

use serde::Deserialize;
use tire_core::contract::{solve_core, ContactSampleRaw, CoreInput, WheelState};
use tire_core::conventions::SimCalibration;

#[derive(Debug, Deserialize)]
struct Expected {
    fx: f32,
    fy: f32,
    fz: f32,
    mz: f32,
    confidence: f32,
}

#[derive(Debug, Deserialize)]
struct Snapshot {
    version: String,
    wheel: WheelState,
    samples: Vec<ContactSampleRaw>,
    expected: Expected,
}

#[test]
fn snapshot_matches_expected_output_with_tolerance() {
    let payload = fs::read_to_string("tests/data/golden_snapshot_v1.json").expect("snapshot file");
    let snapshot: Snapshot = serde_json::from_str(&payload).expect("valid snapshot json");

    let calibration = SimCalibration::default();
    assert_eq!(snapshot.version, calibration.version);

    let input = CoreInput {
        wheel: snapshot.wheel,
        samples: snapshot.samples,
        conventions: calibration.core,
    };

    let out = solve_core(&input);
    let tol = 1.0e-3;

    assert!((out.fx - snapshot.expected.fx).abs() < tol);
    assert!((out.fy - snapshot.expected.fy).abs() < tol);
    assert!((out.fz - snapshot.expected.fz).abs() < tol);
    assert!((out.mz - snapshot.expected.mz).abs() < tol);
    assert!((out.confidence - snapshot.expected.confidence).abs() < tol);
}
