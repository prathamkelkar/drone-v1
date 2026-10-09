#!/usr/bin/env python3
"""Watch and record the sim from several angles at once, in slow motion.

Usage: spectate.py [--out FILE.mp4] [--slowmo N] [--rate HZ] [--no-window] [--keep]
       defaults: --out intercept.mp4  --slowmo 3  --rate 30

Spawns three fixed spectator cameras in Gazebo and shows them, plus the
drone's own camera, as one 2x2 window. The same view is written to --out.
Each frame is one sim camera frame, and the video plays at rate/slowmo fps,
so the default plays back 3x slower than real time. Stop with Ctrl-C, q, or
by closing the window; the spectator cameras are removed on exit unless
--keep. The video is H.264 if ffmpeg is installed (sudo apt install ffmpeg),
which plays everywhere; otherwise OpenCV's mp4v, which many players can't open.

Camera placement assumes the usual test setup: drone hovering ~4 m above
its takeoff point (Gazebo origin) facing +x (east), objects ~1-3 m east of
it (glide_ball.py, launch_ball.py).
  side  - 8 m south, looking north: east-west gap and height
  front - 8 m east, looking west:   north-south gap and height
  top   - 12 m up, looking down:    both horizontal gaps
Each extra camera is rendered by Gazebo, so this adds sim load; lower --rate
if the sim slows down (check its real-time factor).
"""
import argparse
import os
import shutil
import signal
import subprocess
import threading
import time

import cv2
import numpy as np
from gz.msgs10.boolean_pb2 import Boolean
from gz.msgs10.entity_factory_pb2 import EntityFactory
from gz.msgs10.entity_pb2 import Entity
from gz.msgs10.image_pb2 import Image
from gz.transport13 import Node

ap = argparse.ArgumentParser()
ap.add_argument('--out', default='intercept.mp4')
ap.add_argument('--slowmo', type=float, default=3.0)
ap.add_argument('--rate', type=float, default=30.0, help='spectator camera frame rate (sim Hz)')
ap.add_argument('--no-window', action='store_true')
ap.add_argument('--keep', action='store_true', help='leave the spectator cameras in the world on exit')
args = ap.parse_args()
world = os.environ.get('WORLD', 'default')

# gz.msgs.PixelFormatType values (the enum has no importable Python module)
_PIXEL = {v.name: v.number for v in
          Image.DESCRIPTOR.fields_by_name['pixel_format_type'].enum_type.values}
L_INT8, RGB_INT8, BGR_INT8 = _PIXEL['L_INT8'], _PIXEL['RGB_INT8'], _PIXEL['BGR_INT8']

W, H = 640, 480
# name: (x, y, z, roll, pitch, yaw) in Gazebo's frame; a camera looks along its +x
CAMERAS = {
    'side':  (1.25, -8.0, 4.3, 0.0, 0.0, 1.5708),
    'front': (9.0, 0.0, 4.3, 0.0, 0.0, 3.1416),
    'top':   (1.25, 0.0, 12.0, 0.0, 1.5708, 0.0),
}
ONBOARD = f'/world/{world}/model/x500_depth_0/link/camera_link/sensor/IMX214/image'
PANELS = ['side', 'front', 'top', 'onboard']


def camera_sdf(name, pose):
    return f"""<?xml version="1.0"?>
<sdf version="1.9">
  <model name="spectator_{name}">
    <static>true</static>
    <pose>{' '.join(str(v) for v in pose)}</pose>
    <link name="link">
      <sensor name="cam" type="camera">
        <topic>/spectator/{name}</topic>
        <update_rate>{args.rate}</update_rate>
        <always_on>1</always_on>
        <camera>
          <horizontal_fov>1.2</horizontal_fov>
          <image><width>{W}</width><height>{H}</height></image>
          <clip><near>0.1</near><far>200</far></clip>
        </camera>
      </sensor>
    </link>
  </model>
</sdf>"""


def to_bgr(msg: Image):
    """gz.msgs.Image (RGB_INT8 / BGR_INT8 / L_INT8) -> BGR numpy image."""
    ch = {RGB_INT8: 3, BGR_INT8: 3, L_INT8: 1}.get(msg.pixel_format_type)
    if ch is None:
        return None
    step = msg.step or msg.width * ch
    img = np.frombuffer(msg.data, np.uint8).reshape(msg.height, step)[:, :msg.width * ch]
    img = img.reshape(msg.height, msg.width, ch)
    if ch == 1:
        return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    return cv2.cvtColor(img, cv2.COLOR_RGB2BGR) if msg.pixel_format_type == RGB_INT8 else img.copy()


lock = threading.Lock()
latest = {}          # panel -> (BGR image, sim time)
new_side = threading.Event()


def make_cb(panel):
    def cb(msg: Image):
        img = to_bgr(msg)
        if img is None:
            return
        t = msg.header.stamp.sec + msg.header.stamp.nsec * 1e-9
        with lock:
            latest[panel] = (img, t)
        if panel == 'side':
            new_side.set()
    return cb


def remove_cameras(node):
    for name in CAMERAS:
        e = Entity()
        e.name = f'spectator_{name}'
        e.type = Entity.MODEL
        node.request(f'/world/{world}/remove', e, Entity, Boolean, 1000)


def mosaic():
    tiles = []
    with lock:
        snap = dict(latest)
    t_now = snap['side'][1] if 'side' in snap else 0.0
    for panel in PANELS:
        if panel in snap:
            tile = cv2.resize(snap[panel][0], (W, H))
        else:
            tile = np.zeros((H, W, 3), np.uint8)
            cv2.putText(tile, 'no image yet', (20, H // 2), cv2.FONT_HERSHEY_SIMPLEX, 1, (200, 200, 200), 2)
        cv2.putText(tile, panel, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)
        tiles.append(tile)
    img = np.vstack([np.hstack(tiles[:2]), np.hstack(tiles[2:])])
    cv2.putText(img, f'sim t = {t_now:.2f} s   ({args.slowmo:g}x slow motion)', (10, 2 * H - 15),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
    return img


def find_ffmpeg():
    exe = shutil.which('ffmpeg')
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None


class VideoOut:
    """H.264 .mp4 (plays in browsers, phones, messaging apps) via ffmpeg if
    it's available; otherwise OpenCV's MPEG-4 Part 2 ('mp4v'), which many
    players can't open - convert it later with ffmpeg (see README)."""

    def __init__(self, path, fps, size):
        self.proc = None
        self.cv = None
        exe = find_ffmpeg()
        if exe:
            self.proc = subprocess.Popen(
                [exe, '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgr24',
                 '-s', f'{size[0]}x{size[1]}', '-r', f'{fps}', '-i', '-',
                 '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'veryfast', '-crf', '23',
                 '-movflags', '+faststart', path],
                stdin=subprocess.PIPE, start_new_session=True)
            self.kind = 'H.264'
        else:
            self.cv = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*'mp4v'), fps, size)
            self.kind = 'mp4v (no ffmpeg found: many players cannot open this - install ffmpeg)'

    def write(self, img):
        if self.proc:
            self.proc.stdin.write(img.tobytes())
        else:
            self.cv.write(img)

    def release(self):
        if self.proc:
            self.proc.stdin.close()
            self.proc.wait()
        else:
            self.cv.release()


def _stop(signum, frame):
    raise KeyboardInterrupt


def main():
    # Closing the terminal (SIGHUP) or `kill` (SIGTERM) must still finish the
    # video file properly, like Ctrl-C does.
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGHUP, _stop)
    node = Node()
    remove_cameras(node)  # clear leftovers from a previous run
    for name, pose in CAMERAS.items():
        req = EntityFactory()
        req.sdf = camera_sdf(name, pose)
        req.name = f'spectator_{name}'
        ok, _ = node.request(f'/world/{world}/create', req, EntityFactory, Boolean, 3000)
        if not ok:
            raise SystemExit('spawn request failed (is the sim running / world name right?)')
    for name in CAMERAS:
        node.subscribe(Image, f'/spectator/{name}', make_cb(name))
    node.subscribe(Image, ONBOARD, make_cb('onboard'))

    fps = args.rate / args.slowmo
    writer = VideoOut(args.out, fps, (2 * W, 2 * H))
    print(f'Recording to {args.out} [{writer.kind}] at {fps:g} fps '
          f'({args.slowmo:g}x slow motion). Ctrl-C to stop.')
    frames = 0
    try:
        while True:
            if not new_side.wait(timeout=5.0):
                print('no frames from the spectator cameras for 5 s - is the sim running?')
                continue
            new_side.clear()
            img = mosaic()
            writer.write(img)
            frames += 1
            if not args.no_window:
                cv2.imshow('spectate (q to quit)', img)
                key = cv2.waitKey(1) & 0xFF
                # q, or closing the window, ends the recording
                if key == ord('q') or cv2.getWindowProperty('spectate (q to quit)', cv2.WND_PROP_VISIBLE) < 1:
                    break
    except KeyboardInterrupt:
        pass
    finally:
        writer.release()
        cv2.destroyAllWindows()
        if not args.keep:
            remove_cameras(node)
        print(f'wrote {frames} frames to {args.out}')


if __name__ == '__main__':
    main()
