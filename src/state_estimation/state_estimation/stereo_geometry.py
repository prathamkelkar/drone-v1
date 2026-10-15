"""Pure stereo geometry for one tracked ball. No ROS imports, so it runs and tests anywhere.

Per-frame pipeline
------------------
  raw pixel centres (distorted, from the detector)
    -> undistort + rectify      cv2.undistortPoints(uv, K, D, R=R1, P=P1)
    -> pair left and right      rows agree after rectification
    -> triangulate              cv2.triangulatePoints(P1, P2, ...)  -> rectified left frame
    -> rotate back              X_raw = R1^T @ X_rect  -> raw left optical frame

Why undistortPoints and not undistort
-------------------------------------
cv2.undistort remaps a whole image, which costs time every frame. The ball is one point,
so we only need to undistort that point. cv2.undistortPoints does exactly that, using the
same K and D. Note: without the P argument, undistortPoints returns NORMALISED coordinates,
not pixels, so P is always passed here.

Conventions
-----------
* Rectified projection matrices P1 = [f 0 cx 0; 0 f cy 0; 0 0 1 0] and
  P2 = [f 0 cx -f*B; 0 f cy 0; 0 0 1 0]. The left camera is the origin, so P1 has Tx = 0.
* Triangulated points are in the left camera optical frame: x right, y down, z forward.
"""
from dataclasses import dataclass

import numpy as np
import cv2


def _dist(D):
    """CameraInfo.d can be empty for an ideal camera. OpenCV wants 4-14 numbers."""
    if D is None or np.size(D) == 0:
        return np.zeros(5, dtype=np.float64)
    return np.asarray(D, dtype=np.float64).reshape(-1)


def undistort_points(uv, K, D, R, P):
    """Undistort AND rectify pixel points in one call.

    uv: (N, 2) distorted pixel coordinates from the raw image.
    K:  3x3 raw intrinsics (CameraInfo.k).
    D:  distortion coefficients (CameraInfo.d).
    R:  3x3 rectification rotation (R1 for left, R2 for right). Identity if already rectified.
    P:  3x4 rectified projection (P1 or P2). Required, see module docstring.

    Returns (N, 2) rectified pixel coordinates in the frame defined by P.
    """
    pts = np.asarray(uv, dtype=np.float64).reshape(-1, 1, 2)
    out = cv2.undistortPoints(
        pts,
        np.asarray(K, dtype=np.float64),
        _dist(D),
        R=np.asarray(R, dtype=np.float64),
        P=np.asarray(P, dtype=np.float64),
    )
    return out.reshape(-1, 2)


def baseline_from_projection(P_left, P_right):
    """Baseline B in metres from rectified projection matrices (P2[0,3] = -f*B)."""
    f = P_left[0, 0]
    if f <= 0:
        raise ValueError('focal length from P_left must be positive')
    return -P_right[0, 3] / f


@dataclass
class StereoModel:
    P_left: np.ndarray     # 3x4 rectified projection, left
    P_right: np.ndarray    # 3x4 rectified projection, right
    K_left: np.ndarray     # 3x3 raw intrinsics, left
    D_left: np.ndarray     # raw distortion, left
    K_right: np.ndarray    # 3x3 raw intrinsics, right
    D_right: np.ndarray    # raw distortion, right
    R_left: np.ndarray     # 3x3 rectification rotation, left (identity if already rectified)
    R_right: np.ndarray    # 3x3 rectification rotation, right
    undistort: bool        # True: input points are raw/distorted. False: already rectified.

    @property
    def f(self):
        return float(self.P_left[0, 0])

    @property
    def B(self):
        return float(baseline_from_projection(self.P_left, self.P_right))

    def rectify(self, uv, side):
        """Map raw pixel points into the rectified image of the given side."""
        uv = np.asarray(uv, dtype=np.float64).reshape(-1, 2)
        if uv.shape[0] == 0 or not self.undistort:
            return uv
        if side == 'left':
            return undistort_points(uv, self.K_left, self.D_left, self.R_left, self.P_left)
        if side == 'right':
            return undistort_points(uv, self.K_right, self.D_right, self.R_right, self.P_right)
        raise ValueError(f"side must be 'left' or 'right', got {side!r}")

    def to_raw_left_frame(self, X_rect):
        """Rotate a point from the rectified left frame back into the raw left optical frame."""
        return self.R_left.T @ np.asarray(X_rect, dtype=np.float64)


def validate_model(model, min_baseline_m=0.02):
    """Raise ValueError if the calibration can't produce a valid stereo result."""
    P_l, P_r = model.P_left, model.P_right
    if P_l.shape != (3, 4) or P_r.shape != (3, 4):
        raise ValueError('P matrices must be 3x4')
    if model.f <= 0:
        raise ValueError('focal length must be positive (P1[0,0] <= 0; calibration is probably missing)')
    if abs(P_l[0, 3]) > 1e-6 * max(1.0, abs(P_l[0, 0])):
        raise ValueError('P1 must have zero translation: the left camera defines the origin')
    B = model.B
    if B < min_baseline_m:
        raise ValueError(f'baseline {B:.4f} m is below min_baseline_m={min_baseline_m}; '
                         f'check the right camera is on the correct side')
    for name, R in (('R1', model.R_left), ('R2', model.R_right)):
        if R.shape != (3, 3) or not np.allclose(R @ R.T, np.eye(3), atol=1e-6):
            raise ValueError(f'{name} is not a valid rotation matrix (is the calibration filled in?)')
    return None


def pair_detections(left_uv, right_uv, max_row_diff=3.0, min_disparity=1.0, max_disparity=None):
    """Pair the ball detection in the left image with the one in the right image.

    left_uv, right_uv: sequences of (u, v) pixel centres, ALREADY RECTIFIED.
    A valid pair has rows within max_row_diff and disparity u_L - u_R >= min_disparity
    (a point in front of the cameras lands further left in the right image).
    Among valid pairs, the one with the closest rows wins.

    Returns (uL, uR, v) or None.
    """
    best = None
    best_dv = None
    for ul, vl in left_uv:
        for ur, vr in right_uv:
            dv = abs(vl - vr)
            if dv > max_row_diff:
                continue
            d = ul - ur
            if d < min_disparity:
                continue
            if max_disparity is not None and d > max_disparity:
                continue
            if best_dv is None or dv < best_dv:
                best_dv = dv
                best = (float(ul), float(ur), float(0.5 * (vl + vr)))
    return best


def depth_from_disparity(d_px, f_px, baseline_m):
    """Z = f * B / d for rectified, parallel cameras."""
    if d_px <= 0:
        raise ValueError('disparity must be positive')
    return f_px * baseline_m / d_px


def depth_sigma(Z_m, f_px, baseline_m, sigma_d_px):
    """1-sigma depth error from DISPARITY noise: dZ = Z^2 * dd / (f * B).

    sigma_d_px is the std of the disparity itself. If each image point has independent
    noise sigma_p, the disparity std is sqrt(2) * sigma_p.
    """
    return (Z_m ** 2) * sigma_d_px / (f_px * baseline_m)


def triangulate(uvL, uvR, P_left, P_right):
    """Linear (DLT) triangulation of one matched, rectified point pair.

    Returns the 3D point (X, Y, Z) in the frame defined by P_left.
    """
    pl = np.array([[uvL[0]], [uvL[1]]], dtype=np.float64)
    pr = np.array([[uvR[0]], [uvR[1]]], dtype=np.float64)
    hom = cv2.triangulatePoints(np.asarray(P_left, np.float64),
                                np.asarray(P_right, np.float64), pl, pr)
    if abs(hom[3, 0]) < 1e-12:
        raise ValueError('degenerate triangulation (point at infinity)')
    return (hom[:3, 0] / hom[3, 0]).astype(np.float64)


def localize(model, left_uv, right_uv, sigma_d_px=0.5, max_row_diff=3.0, min_disparity=1.0):
    """Full per-frame pipeline: undistort+rectify -> pair -> triangulate -> sigma.

    left_uv, right_uv: lists of RAW pixel centres (one per candidate detection).
    Returns a dict with X, Y, Z (raw left optical frame, metres), sigma_Z, disparity, v,
    or None when there is no valid pair.
    """
    if len(left_uv) == 0 or len(right_uv) == 0:
        return None
    L = model.rectify(left_uv, 'left')
    R = model.rectify(right_uv, 'right')
    pair = pair_detections(L, R, max_row_diff=max_row_diff, min_disparity=min_disparity)
    if pair is None:
        return None
    uL, uR, v = pair
    X_rect = triangulate((uL, v), (uR, v), model.P_left, model.P_right)
    X = model.to_raw_left_frame(X_rect)
    if X[2] <= 0:
        return None
    return {
        'X': float(X[0]), 'Y': float(X[1]), 'Z': float(X[2]),
        'sigma_Z': float(depth_sigma(X_rect[2], model.f, model.B, sigma_d_px)),
        'disparity': float(uL - uR),
        'v': float(v),
    }