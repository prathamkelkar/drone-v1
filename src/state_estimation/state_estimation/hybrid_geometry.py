"""Pure geometry for hybrid ball localisation: one monocular camera plus one depth camera.

Assumes the depth image is ALIGNED to the monocular colour image, e.g. RealSense
align_depth.enable:=true (topic .../aligned_depth_to_color/image_raw). Then the same
pixel indexes both images and the mono intrinsics K apply, so no extrinsics are needed.

Per frame
---------
1. Monocular range:  Z_m = f * W / w   (W = known ball diameter, w = undistorted width in px).
2. Depth range:      median of valid aligned-depth pixels in a disc at the ball centre.
                     Valid = finite and within [depth_min_m, depth_max_m]. The depth camera
                     is only trusted up to about 4 m, so beyond that we use monocular only.
3. Fusion:           inverse-variance when the two agree within gate_sigmas. Otherwise trust
                     the one with the smaller sigma and label the result as gated.
4. Deprojection:     X = Z * xn, Y = Z * yn, using the undistorted normalised ray (xn, yn).

Bearing always comes from the monocular camera. Output is in its optical frame
(x right, y down, z forward).
"""
from dataclasses import dataclass
from typing import Optional

import numpy as np
import cv2


def _dist(D):
    """CameraInfo.d can be empty for an ideal camera. OpenCV wants 4-14 numbers."""
    if D is None or np.size(D) == 0:
        return np.zeros(5, dtype=np.float64)
    return np.asarray(D, dtype=np.float64).reshape(-1)


def normalised_ray(u, v, K, D):
    """Undistorted normalised image coordinates (x/z, y/z) for a raw pixel."""
    pts = np.array([[[u, v]]], dtype=np.float64)
    out = cv2.undistortPoints(pts, np.asarray(K, np.float64), _dist(D))
    return float(out[0, 0, 0]), float(out[0, 0, 1])


def undistorted_width(u, v, width_px, K, D):
    """Ball width in undistorted pixels, from the two edges of the bbox.

    We undistort the edges rather than scaling the bbox size, so lens distortion at the
    edges is handled properly. P=K keeps the output in pixel units.
    """
    K64 = np.asarray(K, np.float64)
    pts = np.array([[[u - width_px / 2.0, v]], [[u + width_px / 2.0, v]]], dtype=np.float64)
    out = cv2.undistortPoints(pts, K64, _dist(D), P=K64)
    return float(abs(out[1, 0, 0] - out[0, 0, 0]))


def monocular_range(f_px, ball_width_m, width_px):
    """Z = f * W / w. Raises if the width is not positive."""
    if width_px <= 0:
        raise ValueError('ball width in pixels must be positive')
    return f_px * ball_width_m / width_px


def monocular_sigma(Z_m, width_px, sigma_width_px, sigma_width_rel):
    """1-sigma range from pixel-width noise and from the known-size uncertainty.

    Relative errors add in quadrature: (dZ/Z)^2 = (dw/w)^2 + (dW/W)^2.
    """
    return Z_m * np.sqrt((sigma_width_px / width_px) ** 2 + sigma_width_rel ** 2)


def depth_sigma(Z_m, k):
    """1-sigma depth error, sigma = k * Z^2. Placeholder: fit k from measured data."""
    return k * Z_m * Z_m


def sample_depth(depth_m, u, v, radius_px, min_range_m, max_range_m, min_valid=10):
    """Median of valid depth pixels in a disc of radius_px around (u, v).

    Returns None when fewer than min_valid pixels are valid. Zeros, NaNs, and anything
    outside [min_range_m, max_range_m] are discarded, so background beyond the sensor's
    trusted range can't contaminate the answer.
    """
    H, W = depth_m.shape
    r = int(np.ceil(radius_px))
    u0, v0 = int(round(u)), int(round(v))
    ys = np.arange(max(0, v0 - r), min(H, v0 + r + 1))
    xs = np.arange(max(0, u0 - r), min(W, u0 + r + 1))
    if ys.size == 0 or xs.size == 0:
        return None
    yy, xx = np.meshgrid(ys, xs, indexing='ij')
    inside = (yy - v) ** 2 + (xx - u) ** 2 <= radius_px ** 2
    vals = depth_m[yy[inside], xx[inside]]
    valid = np.isfinite(vals) & (vals > min_range_m) & (vals <= max_range_m)
    if np.count_nonzero(valid) < min_valid:
        return None
    return float(np.median(vals[valid]))


@dataclass
class RangeEstimate:
    Z: float
    sigma: float
    source: str   # 'fused', 'depth', 'mono', 'depth_gated', 'mono_gated'


def fuse_range(Z_d, s_d, Z_m, s_m, gate_sigmas=3.0):
    """Combine depth-camera and monocular ranges. Either input may be None."""
    if Z_d is None and Z_m is None:
        return None
    if Z_d is None:
        return RangeEstimate(float(Z_m), float(s_m), 'mono')
    if Z_m is None:
        return RangeEstimate(float(Z_d), float(s_d), 'depth')

    s_d = max(float(s_d), 1e-6)
    s_m = max(float(s_m), 1e-6)
    if abs(Z_d - Z_m) <= gate_sigmas * np.hypot(s_d, s_m):
        wd, wm = 1.0 / s_d ** 2, 1.0 / s_m ** 2
        Z = (wd * Z_d + wm * Z_m) / (wd + wm)
        return RangeEstimate(float(Z), float(1.0 / np.sqrt(wd + wm)), 'fused')

    # Disagreement beyond the gate: one sensor is wrong (wrong ball size, occluder,
    # or depth from the background). Trust the more certain one.
    if s_d <= s_m:
        return RangeEstimate(float(Z_d), s_d, 'depth_gated')
    return RangeEstimate(float(Z_m), s_m, 'mono_gated')


@dataclass
class HybridConfig:
    ball_width_m: float = 0.22
    depth_min_m: float = 0.2
    depth_max_m: float = 4.0
    depth_k: float = 0.002
    sigma_width_px: float = 1.0
    sigma_width_rel: float = 0.1
    sample_radius_frac: float = 0.5
    gate_sigmas: float = 3.0
    min_depth_pixels: int = 10


def localize_hybrid(K, D, u, v, width_px, depth_m: Optional[np.ndarray],
                    cfg: HybridConfig = HybridConfig()):
    """Full per-frame estimate in the monocular optical frame.

    u, v, width_px: raw bbox centre and width in pixels.
    depth_m: aligned depth image in metres (2D array), or None for monocular only.
    Returns dict with X, Y, Z, sigma_Z, source, range_mono, range_depth; or None.
    """
    K64 = np.asarray(K, np.float64)
    f = float(K64[0, 0])

    Z_m = s_m = None
    w_und = undistorted_width(u, v, width_px, K64, D)
    if w_und > 0:
        Z_m = monocular_range(f, cfg.ball_width_m, w_und)
        s_m = monocular_sigma(Z_m, w_und, cfg.sigma_width_px, cfg.sigma_width_rel)

    Z_d = s_d = None
    if depth_m is not None:
        radius = cfg.sample_radius_frac * max(width_px, 1.0) / 2.0
        z = sample_depth(depth_m, u, v, radius, cfg.depth_min_m, cfg.depth_max_m,
                         cfg.min_depth_pixels)
        if z is not None:
            Z_d = z
            s_d = depth_sigma(z, cfg.depth_k)

    est = fuse_range(Z_d, s_d, Z_m, s_m, cfg.gate_sigmas)
    if est is None:
        return None

    xn, yn = normalised_ray(u, v, K64, D)
    return {
        'X': float(est.Z * xn),
        'Y': float(est.Z * yn),
        'Z': float(est.Z),
        'sigma_Z': float(est.sigma),
        'source': est.source,
        'range_mono': None if Z_m is None else float(Z_m),
        'range_depth': None if Z_d is None else float(Z_d),
    }