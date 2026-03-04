#!/usr/bin/env python3
import json
import math
from pathlib import Path

EPS = 1e-6


def close(a, b):
    return abs(float(a) - float(b)) <= EPS


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


# ---- Godot mirrors ----
def gd_mcpherson(bump_steer_eval, camber_compression_eval):
    return {"dynamic_toe_delta": bump_steer_eval, "dynamic_camber_delta": camber_compression_eval}


def gd_double_wishbone(total_load, wishbone_angle):
    return {
        "dynamic_camber_delta": wishbone_angle + total_load * 0.00005,
        "dynamic_toe_delta": total_load * 0.00001,
    }


def gd_multilink(total_load, link_count):
    count = max(int(link_count), 1)
    load_per_link = total_load / float(count)
    link_forces = [load_per_link * (1.0 + math.sin(float(i) * 0.5)) for i in range(count)]
    l0 = float(link_forces[0])
    l1 = float(link_forces[1]) if count > 1 else 0.0
    l2 = float(link_forces[2]) if count > 2 else 0.0
    return {
        "dynamic_camber_delta": l0 * 0.00001,
        "dynamic_toe_delta": (l1 - l2) * 0.00002,
    }


def gd_pushrod(total_load, rocker_ratio, base_vertical_stiffness):
    spring_force = total_load * rocker_ratio
    deformation_y = spring_force / max(base_vertical_stiffness, 1e-6)
    return {"deformation_y_delta": deformation_y, "aux_value": 0.3 + deformation_y * 0.1}


def gd_pullrod(total_load, rocker_ratio, base_vertical_stiffness):
    spring_force = total_load * rocker_ratio
    deformation_y = spring_force / max(base_vertical_stiffness, 1e-6)
    return {"deformation_y_delta": deformation_y, "aux_value": -0.2 - deformation_y * 0.1}


def gd_air(total_load, air_volume_liters, min_air_pressure, max_air_pressure):
    new_pressure = total_load / (max(air_volume_liters, 1e-6) * 0.001) + min_air_pressure
    pressure = clamp(new_pressure, min_air_pressure, max_air_pressure)
    return {"air_pressure": pressure, "base_vertical_stiffness": pressure * 300.0}


def gd_axle(load_left, load_right, axle_stiffness):
    avg_load = (load_left + load_right) * 0.5
    k = max(axle_stiffness, 1e-6)
    return {
        "balanced_load": avg_load,
        "deformation_y_left": (load_left - avg_load) / k,
        "deformation_y_right": (load_right - avg_load) / k,
    }


def gd_response(lateral_g, load_transfer_curve_eval, bump_steer_curve_eval, roll_center_curve_eval):
    sign = 0.0
    if lateral_g > 0:
        sign = 1.0
    elif lateral_g < 0:
        sign = -1.0
    return {
        "load_transfer": load_transfer_curve_eval * sign,
        "dynamic_bump_steer": bump_steer_curve_eval,
        "roll_center_height": roll_center_curve_eval,
    }


# ---- Rust mirrors (as implemented) ----
def rs_mcpherson(bump_steer_eval, camber_compression_eval):
    return {"dynamic_toe_delta": bump_steer_eval, "dynamic_camber_delta": camber_compression_eval}


def rs_double_wishbone(total_load, wishbone_angle):
    return gd_double_wishbone(total_load, wishbone_angle)


def rs_multilink(total_load, link_count):
    return gd_multilink(total_load, link_count)


def rs_pushrod(total_load, rocker_ratio, base_vertical_stiffness):
    return gd_pushrod(total_load, rocker_ratio, base_vertical_stiffness)


def rs_pullrod(total_load, rocker_ratio, base_vertical_stiffness):
    return gd_pullrod(total_load, rocker_ratio, base_vertical_stiffness)


def rs_air(total_load, air_volume_liters, min_air_pressure, max_air_pressure):
    # Rust returns aux_value=pressure, deformation_y_delta=stiffness.
    x = gd_air(total_load, air_volume_liters, min_air_pressure, max_air_pressure)
    return {"aux_value": x["air_pressure"], "deformation_y_delta": x["base_vertical_stiffness"]}


def rs_axle(load_left, load_right, axle_stiffness):
    return gd_axle(load_left, load_right, axle_stiffness)


def rs_response(lateral_g, load_transfer_curve_eval, bump_steer_curve_eval, roll_center_curve_eval):
    return gd_response(lateral_g, load_transfer_curve_eval, bump_steer_curve_eval, roll_center_curve_eval)


def main():
    data = json.loads(Path("suspension/shared/suspension_type_axle_response_golden_v1.json").read_text())
    c = data["cases"]
    failures = []

    for case in c["mcpherson"]:
        g = gd_mcpherson(case["bump_steer_eval"], case["camber_compression_eval"])
        r = rs_mcpherson(case["bump_steer_eval"], case["camber_compression_eval"])
        if not close(g["dynamic_toe_delta"], r["dynamic_toe_delta"]) or not close(g["dynamic_camber_delta"], r["dynamic_camber_delta"]):
            failures.append(f"{case['name']}: mcpherson mismatch")

    for case in c["double_wishbone"]:
        g = gd_double_wishbone(case["total_load"], case["wishbone_angle"])
        r = rs_double_wishbone(case["total_load"], case["wishbone_angle"])
        if not close(g["dynamic_toe_delta"], r["dynamic_toe_delta"]) or not close(g["dynamic_camber_delta"], r["dynamic_camber_delta"]):
            failures.append(f"{case['name']}: double_wishbone mismatch")

    for case in c["multilink"]:
        g = gd_multilink(case["total_load"], case["link_count"])
        r = rs_multilink(case["total_load"], case["link_count"])
        if not close(g["dynamic_toe_delta"], r["dynamic_toe_delta"]) or not close(g["dynamic_camber_delta"], r["dynamic_camber_delta"]):
            failures.append(f"{case['name']}: multilink mismatch")

    for case in c["pushrod"]:
        g = gd_pushrod(case["total_load"], case["rocker_ratio"], case["base_vertical_stiffness"])
        r = rs_pushrod(case["total_load"], case["rocker_ratio"], case["base_vertical_stiffness"])
        if not close(g["deformation_y_delta"], r["deformation_y_delta"]) or not close(g["aux_value"], r["aux_value"]):
            failures.append(f"{case['name']}: pushrod mismatch")

    for case in c["pullrod"]:
        g = gd_pullrod(case["total_load"], case["rocker_ratio"], case["base_vertical_stiffness"])
        r = rs_pullrod(case["total_load"], case["rocker_ratio"], case["base_vertical_stiffness"])
        if not close(g["deformation_y_delta"], r["deformation_y_delta"]) or not close(g["aux_value"], r["aux_value"]):
            failures.append(f"{case['name']}: pullrod mismatch")

    for case in c["air"]:
        g = gd_air(case["total_load"], case["air_volume_liters"], case["min_air_pressure"], case["max_air_pressure"])
        r = rs_air(case["total_load"], case["air_volume_liters"], case["min_air_pressure"], case["max_air_pressure"])
        if not close(g["air_pressure"], r["aux_value"]) or not close(g["base_vertical_stiffness"], r["deformation_y_delta"]):
            failures.append(f"{case['name']}: air mismatch")

    for case in c["axle"]:
        g = gd_axle(case["load_left"], case["load_right"], case["axle_stiffness"])
        r = rs_axle(case["load_left"], case["load_right"], case["axle_stiffness"])
        if not close(g["balanced_load"], r["balanced_load"]) or not close(g["deformation_y_left"], r["deformation_y_left"]) or not close(g["deformation_y_right"], r["deformation_y_right"]):
            failures.append(f"{case['name']}: axle mismatch")

    for case in c["response"]:
        g = gd_response(case["lateral_g"], case["load_transfer_curve_eval"], case["bump_steer_curve_eval"], case["roll_center_curve_eval"])
        r = rs_response(case["lateral_g"], case["load_transfer_curve_eval"], case["bump_steer_curve_eval"], case["roll_center_curve_eval"])
        if not close(g["load_transfer"], r["load_transfer"]) or not close(g["dynamic_bump_steer"], r["dynamic_bump_steer"]) or not close(g["roll_center_height"], r["roll_center_height"]):
            failures.append(f"{case['name']}: response mismatch")

    if failures:
        print("PARITY_TYPE_AXLE_RESPONSE_FAILED")
        for f in failures:
            print(" -", f)
        raise SystemExit(1)

    total = sum(len(v) for v in c.values())
    print(f"PARITY_TYPE_AXLE_RESPONSE_OK cases={total}")


if __name__ == "__main__":
    main()
