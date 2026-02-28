var _ve_min_x := 0.0
var _ve_max_x := 1.0
var _ve_y_min := 0.85
var _ve_y_max := 0.85

var _vvt_min_x := 0.0
var _vvt_max_x := 1.0
var _vvt_y_min := 0.0
var _vvt_y_max := 1.0

var _thr_min_x := 0.0
var _thr_max_x := 1.0
var _thr_y_min := 1.0
var _thr_y_max := 1.0

var _int_min_x := 0.0
var _int_max_x := 1.0
var _int_y_min := 0.0
var _int_y_max := 0.0

var _exh_min_x := 0.0
var _exh_max_x := 1.0
var _exh_y_min := 0.0
var _exh_y_max := 0.0

func _cache_curve_endpoints(curve: Curve, default_y: float) -> Dictionary:
    if not curve or curve.get_point_count() == 0:
        return {"min_x": 0.0, "max_x": 1.0, "y_min": default_y, "y_max": default_y}
    var min_x := INF
    var max_x := -INF
    var y_min := default_y
    var y_max := default_y
    for i in range(curve.get_point_count()):
        var pt := curve.get_point_position(i)
        if pt.x < min_x:
            min_x = pt.x
            y_min = pt.y
        if pt.x > max_x:
            max_x = pt.x
            y_max = pt.y
    return {"min_x": min_x, "max_x": max_x, "y_min": y_min, "y_max": y_max}

func _refresh_curve_caches():
    var d
    d = _cache_curve_endpoints(volumetric_efficiency_curve, 0.85)
    _ve_min_x = d.min_x; _ve_max_x = d.max_x; _ve_y_min = d.y_min; _ve_y_max = d.y_max
    d = _cache_curve_endpoints(vvt_advance_curve, 0.0)
    _vvt_min_x = d.min_x; _vvt_max_x = d.max_x; _vvt_y_min = d.y_min; _vvt_y_max = d.y_max
    d = _cache_curve_endpoints(throttle_vvt_influence_curve, 1.0)
    _thr_min_x = d.min_x; _thr_max_x = d.max_x; _thr_y_min = d.y_min; _thr_y_max = d.y_max
    d = _cache_curve_endpoints(intake_cam_curve, 0.0)
    _int_min_x = d.min_x; _int_max_x = d.max_x; _int_y_min = d.y_min; _int_y_max = d.y_max
    d = _cache_curve_endpoints(exhaust_cam_curve, 0.0)
    _exh_min_x = d.min_x; _exh_max_x = d.max_x; _exh_y_min = d.y_min; _exh_y_max = d.y_max

func _sample_ve(t: float) -> float:
    if not volumetric_efficiency_curve:
        return 0.85
    t = clamp(t, 0.0, 1.0)
    if t <= _ve_min_x: return _ve_y_min
    if t >= _ve_max_x: return _ve_y_max
    return volumetric_efficiency_curve.interpolate(t)

func _sample_cam_intake(t: float) -> float:
    if not intake_cam_curve:
        return 0.0
    t = clamp(t, 0.0, 1.0)
    if t <= _int_min_x or t >= _int_max_x:
        return 0.0
    return intake_cam_curve.interpolate(t)

func _sample_cam_exhaust(t: float) -> float:
    if not exhaust_cam_curve:
        return 0.0
    t = clamp(t, 0.0, 1.0)
    if t <= _exh_min_x or t >= _exh_max_x:
        return 0.0
    return exhaust_cam_curve.interpolate(t)

func get_volumetric_efficiency(rpm_normalized: float) -> float:
    var q = snapped(rpm_normalized, 0.001)  # 0.1% resolution
    if is_equal_approx(q, _ve_cache_param):
        return _ve_cache_value
    _ve_cache_value = _sample_ve(q)
    _ve_cache_param = q
    return _ve_cache_value

func update_valve_states(angle_norm: float):
    var intake_lift = _sample_cam_intake(angle_norm)
    var exhaust_lift = _sample_cam_exhaust(angle_norm)

    # existing code here
    
    # Call refresh function at the end
    _refresh_curve_caches()
