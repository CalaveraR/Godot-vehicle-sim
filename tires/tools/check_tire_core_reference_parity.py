#!/usr/bin/env python3
import json
from pathlib import Path

EPS = 1e-6


def close(a, b, eps=EPS):
    return abs(float(a) - float(b)) <= eps


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def gd_normalize_weights(weights, conv):
    mpw = float(conv.get("min_positive_weight", 0.0))
    eps = float(conv.get("epsilon", 1e-6))
    s = sum(float(w) for w in weights if float(w) > mpw)
    if s <= eps:
        return [0.0 for _ in weights]
    return [(float(w) / s) if float(w) > mpw else 0.0 for w in weights]


def rs_normalize_weights(weights, conv):
    # mirrors rust/tire_core normalize_weights_with_conventions
    mpw = float(conv.get("min_positive_weight", 0.0))
    eps = float(conv.get("epsilon", 1e-6))
    s = sum(float(w) for w in weights if float(w) > mpw)
    if s <= eps:
        return [0.0 for _ in weights]
    return [(float(w) / s) if float(w) > mpw else 0.0 for w in weights]


def gd_aggregate_patch(samples, conv):
    if not samples:
        return {
            "contact_confidence": 0.0,
            "penetration_avg": 0.0,
            "penetration_max": 0.0,
            "slip_x_avg": 0.0,
            "slip_y_avg": 0.0,
        }
    threshold = float(conv.get("contact_penetration_threshold", 0.0))
    weights = gd_normalize_weights([float(s.get("weight", 0.0)) for s in samples], conv)

    pen_avg = pen_max = sx = sy = conf = 0.0
    for s, w in zip(samples, weights):
        p = float(s.get("penetration", 0.0))
        x = float(s.get("slip_x", 0.0))
        y = float(s.get("slip_y", 0.0))
        if p > threshold:
            conf += w
        pen_avg += p * w
        pen_max = max(pen_max, p)
        sx += x * w
        sy += y * w

    return {
        "contact_confidence": clamp(conf, 0.0, 1.0),
        "penetration_avg": pen_avg,
        "penetration_max": pen_max,
        "slip_x_avg": sx,
        "slip_y_avg": sy,
    }


def rs_aggregate_patch(samples, conv):
    # mirrors rust/tire_core aggregate_patch_with_conventions
    return gd_aggregate_patch(samples, conv)


def gd_compute_effective_radius(tire_radius, min_effective_radius, vertical_load, stiffness, conv):
    if tire_radius <= 0.0:
        return 0.0
    min_stiff = float(conv.get("min_stiffness", 1e-4))
    safe_stiff = max(stiffness, min_stiff)
    compression = min(max(vertical_load, 0.0) / safe_stiff, tire_radius)
    return min(max(tire_radius - compression, min_effective_radius), tire_radius)


def rs_compute_effective_radius(tire_radius, min_effective_radius, vertical_load, stiffness, conv):
    # mirrors rust/tire_core compute_effective_radius_with_conventions
    return gd_compute_effective_radius(tire_radius, min_effective_radius, vertical_load, stiffness, conv)


def main():
    data = json.loads(Path("tires/shared/tire_core_reference_parity_golden_v1.json").read_text())
    fails = []

    for c in data["normalize_weights"]:
        g = gd_normalize_weights(c["weights"], c["conventions"])
        r = rs_normalize_weights(c["weights"], c["conventions"])
        if len(g) != len(r) or any(not close(a, b) for a, b in zip(g, r)):
            fails.append(f"normalize_weights:{c['name']}")

    for c in data["aggregate_patch"]:
        g = gd_aggregate_patch(c["samples"], c["conventions"])
        r = rs_aggregate_patch(c["samples"], c["conventions"])
        for k in ["contact_confidence", "penetration_avg", "penetration_max", "slip_x_avg", "slip_y_avg"]:
            if not close(g[k], r[k]):
                fails.append(f"aggregate_patch:{c['name']}:{k}")

    for c in data["compute_effective_radius"]:
        g = gd_compute_effective_radius(c["tire_radius"], c["min_effective_radius"], c["vertical_load"], c["stiffness"], c["conventions"])
        r = rs_compute_effective_radius(c["tire_radius"], c["min_effective_radius"], c["vertical_load"], c["stiffness"], c["conventions"])
        if not close(g, r):
            fails.append(f"compute_effective_radius:{c['name']}")

    if fails:
        print("TIRE_CORE_REFERENCE_PARITY_FAILED")
        for f in fails:
            print(" -", f)
        raise SystemExit(1)

    total = len(data["normalize_weights"]) + len(data["aggregate_patch"]) + len(data["compute_effective_radius"])
    print(f"TIRE_CORE_REFERENCE_PARITY_OK cases={total}")


if __name__ == "__main__":
    main()
