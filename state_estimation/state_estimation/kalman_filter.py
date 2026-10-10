"""
Constant-velocity / ballistic point-mass Kalman filter (pure numpy, no ROS).

State x = [px, py, pz, vx, vy, vz] in the ENU world frame (z up).
'g' is the gravity MAGNITUDE (>= 0); it is applied as a -z acceleration
once the object is seen moving downward.
"""
import numpy as np


class KalmanFilter():
    def __init__(self, g=9.81):

        self.g = g
        self.x = np.zeros((6, 1))
        self.P = np.eye(6) * 10
        self.Q = np.diag([0.01, 0.01, 0.01,
                          0.1, 0.1, 0.1])

        # Velocity magnitude (m/s) that must be exceeded, downward, before
        # the filter starts applying gravity in predict(). The world frame
        # is ENU, so z points UP and falling means negative vz. Tune based on
        # your measurement noise floor — should be comfortably above the
        # velocity jitter you see while the object is genuinely at rest.
        self.VZ_THRESHOLD = 0.3
        self.in_flight = False

    def initialize(self, z: np.ndarray):
        self.x[0:3] = z
        self.x[3:6] = 0.0
        # Position is known to ~0.1 m from the first detection, but velocity
        # is unknown (could be a fast throw): a large velocity variance makes
        # the filter lock onto the velocity within 1-2 updates. The old
        # eye(6)*10 made it need ~5+ updates, far more than a ball in view
        # for ~1 s at ~5-8 Hz ever provides.
        self.P = np.diag([0.1, 0.1, 0.1, 100.0, 100.0, 100.0])
        # Object starts assumed stationary/at rest — gravity is gated off
        # until real downward motion is detected, so a resting object
        # doesn't get dragged down by a freefall assumption that doesn't
        # apply yet.
        self.in_flight = False

    def predict(self, dt):

        F = np.array([
            [1, 0, 0, dt, 0,  0 ],
            [0, 1, 0, 0,  dt, 0 ],
            [0, 0, 1, 0,  0,  dt],
            [0, 0, 0, 1,  0,  0 ],
            [0, 0, 0, 0,  1,  0 ],
            [0, 0, 0, 0,  0,  1 ],
        ])

        # Control input: z acceleration. ENU: z is up, so gravity (u = -g)
        # accelerates the object toward -z.
        B = np.array([
            [0],
            [0],
            [0.5 * dt**2],
            [0],
            [0],
            [dt],
        ])

        # Check current velocity estimate to decide whether the object is
        # actually in flight yet. vz below -VZ_THRESHOLD means real
        # downward motion has started (z is up in this ENU frame).
        vz = self.x[5, 0]
        if not self.in_flight and vz < -self.VZ_THRESHOLD:
            self.in_flight = True

        u = -self.g if self.in_flight else 0.0

        self.x = F @ self.x + B * u

        self.P = F @ self.P @ F.T + self.Q

    def update(self, z):

        H = np.array([
            [1, 0, 0, 0, 0, 0],
            [0, 1, 0, 0, 0, 0],
            [0, 0, 1, 0, 0, 0],
        ])

        R = np.diag([0.05, 0.05, 0.15])

        y = z - H @ self.x
        S = H @ self.P @ H.T + R

        K = self.P @ H.T @ np.linalg.inv(S)

        self.x = self.x + K @ y
        self.P = (np.eye(6) - K @ H) @ self.P
