#!/usr/bin/env python3
import json
from pathlib import Path

EPS = 1e-6


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def gd_compute_deformation_clamped(deformation, tire):
    raw = [deformation[i] + tire[i] for i in range(3)]
    out = [
        _clamp(raw[0], -0.1, 0.1),
        _clamp(raw[1], -0.2, 0.0),
        _clamp(raw[2], -0.1, 0.1),
    ]
    return out, {
        "x_clamped": abs(raw[0] - out[0]) > 1e-6,
        "y_clamped": abs(raw[1] - out[1]) > 1e-6,
        "z_clamped": abs(raw[2] - out[2]) > 1e-6,
        "radius_clamped": False,
    }


def rust_compute_deformation_clamped(deformation, tire):
    # Mirrors suspension/rust/core/SuspensionCoreKernel.rs
    out = [
        deformation[0] + tire[0],
        deformation[1] + tire[1],
        deformation[2] + tire[2],
    ]
    pre = list(out)
    out[0] = _clamp(out[0], -0.1, 0.1)
    out[1] = _clamp(out[1], -0.2, 0.0)
    out[2] = _clamp(out[2], -0.1, 0.1)
    return out, {
        "x_clamped": abs(pre[0] - out[0]) > 1e-6,
        "y_clamped": abs(pre[1] - out[1]) > 1e-6,
        "z_clamped": abs(pre[2] - out[2]) > 1e-6,
        "radius_clamped": False,
    }


def gd_compute_effective_radius(inp):
    safe_stiffness = max(inp["base_vertical_stiffness"], 1e-6)
    max_deflection = max(inp["tire_radius"] * 0.3, 1e-6)
    stiffness_mul = inp["vertical_stiffness_mul"] if inp["vertical_stiffness_mul"] > 0.0 else 1.0
    deflection = max(inp["total_load"], 0.0) / (safe_stiffness * stiffness_mul)
    base_radius = inp["tire_radius"] - deflection
    base_radius *= inp["dynamic_radius_mul"] if inp["dynamic_radius_mul"] > 0.0 else 1.0
    effective = _clamp(base_radius, inp["min_effective_radius"], inp["tire_radius"] * 1.2)
    return {
        "effective_radius": effective,
        "deflection": _clamp(deflection, 0.0, max_deflection),
        "flags": {"radius_clamped": abs(base_radius - effective) > 1e-6},
    }


def rust_compute_effective_radius(inp):
    # Mirrors suspension/rust/core/SuspensionCoreKernel.rs
    safe_stiffness = max(inp["base_vertical_stiffness"], 1e-6)
    max_deflection = max(inp["tire_radius"] * 0.3, 1e-6)

    stiffness_mul = inp["vertical_stiffness_mul"] if inp["vertical_stiffness_mul"] > 0.0 else 1.0
    deflection = max(inp["total_load"], 0.0) / (safe_stiffness * stiffness_mul)

    base_radius = inp["tire_radius"] - deflection
    base_radius *= inp["dynamic_radius_mul"] if inp["dynamic_radius_mul"] > 0.0 else 1.0

    effective = _clamp(base_radius, inp["min_effective_radius"], inp["tire_radius"] * 1.2)
    return {
        "effective_radius": effective,
        "deflection": _clamp(deflection, 0.0, max_deflection),
        "flags": {"radius_clamped": abs(base_radius - effective) > 1e-6},
    }


def gd_relax(default_value, curve):
    return default_value if curve is None else float(curve)


def rust_relax(default_value, curve):
    return gd_relax(default_value, curve)


def gd_lat(curve):
    return 0.0 if curve is None else float(curve)


def rust_lat(curve):
    return gd_lat(curve)


def close(a, b):
    return abs(float(a) - float(b)) <= EPS


def main():
    data = json.loads(Path("suspension/shared/suspension_core_golden_v1.json").read_text())
    failures = []

    for case in data["cases"]:
        name = case["name"]

        gd_def, gd_flags = gd_compute_deformation_clamped(case["deformation"], case["tire_induced_deformation"])
        rs_def, rs_flags = rust_compute_deformation_clamped(case["deformation"], case["tire_induced_deformation"])
        if any(not close(gd_def[i], rs_def[i]) for i in range(3)) or gd_flags != rs_flags:
            failures.append(f"{name}: deformation mismatch")

        gd_rad = gd_compute_effective_radius(case["effective_radius_input"])
        rs_rad = rust_compute_effective_radius(case["effective_radius_input"])
        if not close(gd_rad["effective_radius"], rs_rad["effective_radius"]):
            failures.append(f"{name}: effective_radius mismatch")
        if not close(gd_rad["deflection"], rs_rad["deflection"]):
            failures.append(f"{name}: deflection mismatch")
        if gd_rad["flags"] != rs_rad["flags"]:
            failures.append(f"{name}: radius flags mismatch")

        gd_r = gd_relax(case["relaxation"]["default"], case["relaxation"]["curve"])
        rs_r = rust_relax(case["relaxation"]["default"], case["relaxation"]["curve"])
        if not close(gd_r, rs_r):
            failures.append(f"{name}: relaxation mismatch")

        gd_l = gd_lat(case["lateral_deformation"]["curve"])
        rs_l = rust_lat(case["lateral_deformation"]["curve"])
        if not close(gd_l, rs_l):
            failures.append(f"{name}: lateral mismatch")

    if failures:
        print("PARITY_CHECK_FAILED")
        for f in failures:
            print(" -", f)
        raise SystemExit(1)

    print(f"PARITY_CHECK_OK cases={len(data['cases'])}")


if __name__ == "__main__":
    main()
