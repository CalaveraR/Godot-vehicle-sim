# Suspension Rust Migration Plan

## Goal
Move all pure numerical suspension logic to Rust while keeping Godot as single authority for:
- Scene I/O
- RayCast
- Force application
- Node orchestration

---

## 1. Separation of Responsibilities

### Godot (Authoritative Layer)
- RayCast creation and direction updates
- Scene transforms
- Connected wheel lookup (solid axle)
- Force application to RigidBody3D
- Curve authoring and interpolation

### Rust (Numerical Core)
- Deformation clamping
- Effective radius computation
- Relaxation factor
- Lateral deformation
- Type-specific geometry (McPherson, DW, MultiLink, Push/PullRod, Air)
- Axle load equalization
- Response system calculations

---

## 2. Core Modules

### suspension_core
Pure per-wheel calculations.

### suspension_types
Geometry models for each suspension type.

### axle_core
Solid axle and future anti-roll logic.

### suspension_response_core
Dynamic load transfer, bump steer response.

---

## 3. Execution Order (Per Tick)

1. Inputs gathered in Godot.
2. suspension_core.solve()
3. suspension_types.apply()
4. suspension_response_core.solve()
5. axle_core.solve() (if needed)
6. Godot applies results to node state and raycast.
7. Wheel/Tire consume updated suspension outputs.

---

## 4. Backend Modes

- GDSCRIPT
- RUST
- SHADOW_COMPARE

Shadow mode logs delta without altering runtime behavior.

---

## 5. Invariants

- No NaN or Inf outputs
- effective_radius bounded
- deformation clamped
- consistent behavior under no-contact conditions

---

## 6. Golden Testing

- Snapshot inputs from Godot
- Validate Rust output within tolerance
- Calibration loaded from shared JSON file
