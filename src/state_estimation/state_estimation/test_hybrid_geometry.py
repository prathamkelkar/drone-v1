"""Tests for hybrid_geometry. Run: python3 -I test_hybrid_geometry.py  (or pytest)."""
import os
import sys

import numpy as np
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))

from hybrid_geometry import (  # noqa: E402
    HybridConfig, localize_hybrid, fuse_range, sample_depth, monocular_range,
    monocular_sigma, depth_sigma, normalised_ray, undistorted_width)

W_IMG, H_IMG = 640, 480
F = 600.0
K = np.array([[F, 0, 320.0], [0, F, 240.0], [0, 0, 1.0]])
D = np.array([-0.15, 0.03, 0.001, -0.0005, 0.0])
BALL = 0.22


def render(X, ball_w=BALL, depth_bg=10.0):
    """Simulate the raw (distorted) bbox centre, raw width, and aligned depth image for a
    ball whose centre is X in the camera frame. Background sits at 10 m, beyond the sensor's range."""
    zero = np.zeros(3)
    c, _ = cv2.projectPoints(X.reshape(1, 1, 3), zero, zero, K, D)
    u, v = c.reshape(2)
    pl, _ = cv2.projectPoints((X - [ball_w / 2, 0, 0]).reshape(1, 1, 3), zero, zero, K, D)
    pr, _ = cv2.projectPoints((X + [ball_w / 2, 0, 0]).reshape(1, 1, 3), zero, zero, K, D)
    width = abs(pr.reshape(2)[0] - pl.reshape(2)[0])
    depth = np.full((H_IMG, W_IMG), depth_bg, np.float32)
    cv2.circle(depth, (int(round(u)), int(round(v))), int(round(width / 2)), float(X[2]), -1)
    return u, v, width, depth


def test_near_fuses_and_is_more_certain_than_either():
    X = np.array([0.10, -0.05, 2.0])
    u, v, w, depth = render(X)
    res = localize_hybrid(K, D, u, v, w, depth)
    assert res['source'] == 'fused', res
    assert abs(res['Z'] - 2.0) < 1e-3, res['Z']
    assert abs(res['X'] - 0.10) < 1e-3 and abs(res['Y'] + 0.05) < 1e-3
    s_depth = depth_sigma(2.0, 0.002)
    s_mono = monocular_sigma(2.0, undistorted_width(u, v, w, K, D), 1.0, 0.1)
    assert res['sigma_Z'] < min(s_depth, s_mono), (res['sigma_Z'], s_depth, s_mono)


def test_far_uses_monocular_only():
    X = np.array([0.3, 0.2, 6.0])          # beyond the 4 m depth range
    u, v, w, depth = render(X)
    res = localize_hybrid(K, D, u, v, w, depth)
    assert res['source'] == 'mono', res['source']
    assert res['range_depth'] is None
    assert abs(res['Z'] - 6.0) < 1e-3


def test_wrong_ball_size_is_absorbed_by_depth():
    X = np.array([0.0, 0.0, 2.0])
    u, v, w, depth = render(X, ball_w=BALL)
    cfg = HybridConfig(ball_width_m=0.30)          # the monocular size assumption is wrong
    res = localize_hybrid(K, D, u, v, w, depth, cfg)
    assert abs(res['Z'] - 2.0) < 0.02, res['Z']    # depth dominates at this range


def test_grossly_wrong_size_is_gated_out():
    X = np.array([0.0, 0.0, 2.0])
    u, v, w, depth = render(X, ball_w=BALL)
    cfg = HybridConfig(ball_width_m=0.50)          # mono says ~4.5 m, depth says 2 m
    res = localize_hybrid(K, D, u, v, w, depth, cfg)
    assert res['source'] == 'depth_gated', res['source']
    assert abs(res['Z'] - 2.0) < 1e-3


def test_depth_sampling_discards_invalid_values():
    patch = np.zeros((50, 50), np.float32)
    patch[20:30, 20:30] = np.nan
    patch[10:20, 10:20] = 9.0      # beyond max range: must be ignored
    assert sample_depth(patch, 25, 25, 12, 0.2, 4.0, min_valid=10) is None
    patch[10:20, 10:20] = 1.5      # now valid
    z = sample_depth(patch, 15, 15, 8, 0.2, 4.0, min_valid=10)
    assert z is not None and abs(z - 1.5) < 1e-6


def test_fusion_is_inverse_variance():
    est = fuse_range(2.0, 0.1, 2.2, 0.1, gate_sigmas=3.0)
    assert est.source == 'fused'
    assert abs(est.Z - 2.1) < 1e-9                   # equal weights: midpoint
    assert abs(est.sigma - 0.1 / np.sqrt(2)) < 1e-9


def test_fusion_handles_missing_inputs():
    assert fuse_range(None, None, None, None) is None
    assert fuse_range(None, None, 3.0, 0.2).source == 'mono'
    assert fuse_range(2.0, 0.05, None, None).source == 'depth'


def test_deprojection_with_distortion_is_exact():
    rng = np.random.default_rng(3)
    for _ in range(100):
        X = np.array([rng.uniform(-0.3, 0.3), rng.uniform(-0.2, 0.2), rng.uniform(1.5, 3.5)])
        u, v, w, depth = render(X)
        res = localize_hybrid(K, D, u, v, w, depth)
        assert np.linalg.norm(np.array([res['X'], res['Y'], res['Z']]) - X) < 1e-3


def test_fusion_beats_each_sensor_in_monte_carlo():
    """Noise on both sensors at 2 m. The fused RMSE must beat each sensor alone."""
    rng = np.random.default_rng(7)
    Z_true, w_true = 2.0, F * BALL / 2.0
    cfg = HybridConfig()
    err_m, err_d, err_f = [], [], []
    for _ in range(4000):
        w = w_true + rng.normal(0, cfg.sigma_width_px)
        Z_m = monocular_range(F, BALL, w)
        s_m = monocular_sigma(Z_m, w, cfg.sigma_width_px, cfg.sigma_width_rel)
        Z_d = Z_true + rng.normal(0, depth_sigma(Z_true, cfg.depth_k))
        s_d = depth_sigma(Z_d, cfg.depth_k)
        f = fuse_range(Z_d, s_d, Z_m, s_m, cfg.gate_sigmas)
        err_m.append(Z_m - Z_true)
        err_d.append(Z_d - Z_true)
        err_f.append(f.Z - Z_true)
    rmse = lambda e: float(np.sqrt(np.mean(np.square(e))))
    assert rmse(err_f) < rmse(err_m), (rmse(err_f), rmse(err_m))
    assert rmse(err_f) < rmse(err_d), (rmse(err_f), rmse(err_d))


if __name__ == '__main__':
    failures = []
    for name, fn in list(globals().items()):
        if name.startswith('test_') and callable(fn):
            try:
                fn()
                print('PASS', name)
            except AssertionError as e:
                failures.append(name)
                print('FAIL', name, e)
    print('ALL PASS' if not failures else f'FAILED: {failures}')