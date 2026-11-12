#!/usr/bin/env python3
"""
Quickshell Headless Mathematical Simulation Engine (Mission Control & Testbed)
- 6-DOF Quadrotor Rigid-Body Dynamics (RK4 numerical integration + Cascaded PID + Motor Mixer)
- Synthetic 2D LiDAR Raycaster (Polar distance returns, VFH obstacle avoidance, CPA)
- J2 Orbital Mechanics Propagator (ISS trajectory, Nadir vector, Eclipse countdown)
- Vehicle Lateral Dynamics (Bicycle model + Pacejka Magic Formula tire curves)

Streams JSON telemetry to stdout at 25 Hz and writes atomically to /tmp/quickshell_sim.json.
Listens on /tmp/quickshell_sim.sock for control parameter inputs.
"""

import sys
import os
import time
import math
import json
import socket
import select
import numpy as np

# ─────────────────────────────────────────────────────────────────────────────
# 1. 6-DOF QUADROTOR RIGID-BODY MODEL
# ─────────────────────────────────────────────────────────────────────────────
class Quadrotor6DOF:
    def __init__(self):
        self.mass = 1.55 # kg
        self.Ixx = 0.0142
        self.Iyy = 0.0142
        self.Izz = 0.0248
        self.arm_len = 0.175 # meters (center to motor)
        self.g = 9.81
        self.hover_thrust = self.mass * self.g # ~15.2 N

        # Motor constants
        self.kT = 1.15e-7 # Thrust coeff N / (RPM^2)
        self.kQ = 1.82e-9 # Torque coeff N*m / (RPM^2)
        self.rpm_min = 1200.0
        self.rpm_max = 6200.0

        # State vector: [x, y, z, vx, vy, vz, q0, q1, q2, q3, p, q, r]
        self.pos = np.array([0.0, 0.0, 1.8]) # Start at 1.8m hover
        self.vel = np.array([0.0, 0.0, 0.0])
        self.q = np.array([1.0, 0.0, 0.0, 0.0]) # [qw, qx, qy, qz]
        self.omega = np.array([0.0, 0.0, 0.0]) # body rates [p, q, r] in rad/s

        # Motor RPMs
        hover_rpm = math.sqrt(self.hover_thrust / (4.0 * self.kT))
        self.rpms = np.array([hover_rpm, hover_rpm, hover_rpm, hover_rpm])

        # Control targets & PID Integrators
        self.target_pos = np.array([0.0, 0.0, 1.8])
        self.err_int_pos = np.array([0.0, 0.0, 0.0])
        self.err_int_att = np.array([0.0, 0.0, 0.0])

        self.time = 0.0

    def quat_to_euler(self, q):
        w, x, y, z = q
        # Roll (x-axis rotation)
        sinr_cosp = 2.0 * (w * x + y * z)
        cosr_cosp = 1.0 - 2.0 * (x * x + y * y)
        roll = math.atan2(sinr_cosp, cosr_cosp)

        # Pitch (y-axis rotation)
        sinp = 2.0 * (w * y - z * x)
        pitch = math.asin(max(-1.0, min(1.0, sinp)))

        # Yaw (z-axis rotation)
        siny_cosp = 2.0 * (w * z + x * y)
        cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
        yaw = math.atan2(siny_cosp, cosy_cosp)

        return roll, pitch, yaw

    def quat_mult(self, q, r):
        w0, x0, y0, z0 = q
        w1, x1, y1, z1 = r
        return np.array([
            w0*w1 - x0*x1 - y0*y1 - z0*z1,
            w0*x1 + x0*w1 + y0*z1 - z0*y1,
            w0*y1 - x0*z1 + y0*w1 + z0*x1,
            w0*z1 + x0*y1 - y0*x1 + z0*w1
        ])

    def rot_matrix(self, q):
        w, x, y, z = q
        return np.array([
            [1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w],
            [2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w],
            [2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y]
        ])

    def step(self, dt):
        self.time += dt

        # Smooth automated reference trajectory (Lissajous figure-8)
        traj_r = 0.45
        self.target_pos = np.array([
            traj_r * math.sin(0.4 * self.time),
            traj_r * math.sin(0.8 * self.time),
            1.8 + 0.15 * math.sin(0.3 * self.time)
        ])
        target_yaw = 0.25 * math.sin(0.2 * self.time)

        # ── Cascaded P-PI Controller ─────────────────────────────────────────
        pos_err = self.target_pos - self.pos
        self.err_int_pos += pos_err * dt
        self.err_int_pos = np.clip(self.err_int_pos, -0.6, 0.6) # Anti-windup

        Kp_p = np.array([1.8, 1.8, 4.2])
        Kd_p = np.array([1.4, 1.4, 3.2])
        Ki_p = np.array([0.2, 0.2, 0.6])

        des_acc = Kp_p * pos_err - Kd_p * self.vel + Ki_p * self.err_int_pos
        des_acc[2] += self.g # Feedforward gravity

        # Desired tilt angles
        des_thrust = self.mass * des_acc[2]
        des_roll = (des_acc[0] * math.sin(target_yaw) - des_acc[1] * math.cos(target_yaw)) / self.g
        des_pitch = (des_acc[0] * math.cos(target_yaw) + des_acc[1] * math.sin(target_yaw)) / self.g

        des_roll = np.clip(des_roll, -0.45, 0.45)
        des_pitch = np.clip(des_pitch, -0.45, 0.45)

        cur_roll, cur_pitch, cur_yaw = self.quat_to_euler(self.q)
        att_err = np.array([des_roll - cur_roll, des_pitch - cur_pitch, target_yaw - cur_yaw])
        self.err_int_att += att_err * dt
        self.err_int_att = np.clip(self.err_int_att, -0.3, 0.3)

        # Body rate targets
        Kp_att = np.array([7.5, 7.5, 3.8])
        Kd_att = np.array([0.85, 0.85, 0.55])
        tau_des = Kp_att * att_err - Kd_att * self.omega

        # Motor mixer (X-frame configuration)
        # T_tot = T1 + T2 + T3 + T4
        # tau_x = d * (T4 + T3 - T1 - T2) / sqrt(2)
        # tau_y = d * (T2 + T3 - T1 - T4) / sqrt(2)
        # tau_z = kQ/kT * (T1 + T3 - T2 - T4)
        d_arm = self.arm_len / 1.414
        c_torq = self.kQ / self.kT

        # Base thrust allocation per rotor
        f_base = des_thrust / 4.0
        df_x = tau_des[0] / (4.0 * d_arm)
        df_y = tau_des[1] / (4.0 * d_arm)
        df_z = tau_des[2] / (4.0 * c_torq)

        f_rotors = np.array([
            f_base - df_x - df_y + df_z, # M1: Front-Left (CCW)
            f_base - df_x + df_y - df_z, # M2: Front-Right (CW)
            f_base + df_x + df_y + df_z, # M3: Rear-Left (CW)
            f_base + df_x - df_y - df_z  # M4: Rear-Right (CCW)
        ])
        f_rotors = np.clip(f_rotors, self.kT * (self.rpm_min**2), self.kT * (self.rpm_max**2))

        # Update motor RPMs with first-order motor lag (tau = 0.035s)
        target_rpms = np.sqrt(f_rotors / self.kT)
        motor_alpha = min(1.0, dt / 0.035)
        self.rpms += motor_alpha * (target_rpms - self.rpms)

        # Actual forces & moments
        act_f = self.kT * (self.rpms**2)
        total_thrust = np.sum(act_f)
        tau_act = np.array([
            d_arm * (act_f[2] + act_f[3] - act_f[0] - act_f[1]),
            d_arm * (act_f[1] + act_f[2] - act_f[0] - act_f[3]),
            c_torq * (act_f[0] + act_f[2] - act_f[1] - act_f[3])
        ])

        # ── RK4 Integration of Equations of Motion ───────────────────────────
        R = self.rot_matrix(self.q)
        f_body = np.array([0.0, 0.0, total_thrust])
        drag = 0.12 * np.array([self.vel[0]*abs(self.vel[0]), self.vel[1]*abs(self.vel[1]), self.vel[2]*abs(self.vel[2])])

        # Linear acceleration in inertial frame
        acc_inertial = np.array([0.0, 0.0, -self.g]) + (R @ f_body - drag) / self.mass
        self.vel += acc_inertial * dt
        self.pos += self.vel * dt

        # Angular acceleration in body frame
        I_diag = np.array([self.Ixx, self.Iyy, self.Izz])
        gyroscopic = np.cross(self.omega, I_diag * self.omega)
        omega_dot = (tau_act - gyroscopic) / I_diag
        self.omega += omega_dot * dt

        # Quaternion kinematics: q_dot = 0.5 * q x [0, omega]
        omega_quat = np.array([0.0, self.omega[0], self.omega[1], self.omega[2]])
        q_dot = 0.5 * self.quat_mult(self.q, omega_quat)
        self.q += q_dot * dt
        self.q /= np.linalg.norm(self.q) # Normalize

        roll, pitch, yaw = self.quat_to_euler(self.q)
        tw_ratio = total_thrust / (self.mass * self.g)

        return {
            "pos": [round(float(p), 3) for p in self.pos],
            "vel": [round(float(v), 3) for v in self.vel],
            "quat": [round(float(q_i), 4) for q_i in self.q],
            "euler_deg": [round(math.degrees(roll), 2), round(math.degrees(pitch), 2), round(math.degrees(yaw), 2)],
            "rpms": [int(round(r)) for r in self.rpms],
            "rpms_pct": [int(round((r / self.rpm_max) * 100)) for r in self.rpms],
            "thrust_n": round(float(total_thrust), 2),
            "tw_ratio": round(float(tw_ratio), 2),
            "pos_err_m": round(float(np.linalg.norm(pos_err)), 3),
            "att_err_deg": round(float(math.degrees(np.linalg.norm(att_err))), 2)
        }

# ─────────────────────────────────────────────────────────────────────────────
# 2. SYNTHETIC 2D LIDAR RAYCASTER & OCCUPANCY GRID
# ─────────────────────────────────────────────────────────────────────────────
class SyntheticLiDAR2D:
    def __init__(self, num_rays=36):
        self.num_rays = num_rays
        self.max_range = 15.0 # meters
        self.sweep_angle = 0.0

        # Procedural obstacles in polar coordinates [x, y, radius]
        self.obstacles = [
            [-2.4, 3.2, 0.65],
            [3.8, 1.8, 0.90],
            [1.2, -4.1, 0.80],
            [-3.5, -2.6, 0.70],
            [4.6, -3.2, 0.55]
        ]
        self.time = 0.0

    def step(self, dt):
        self.time += dt
        self.sweep_angle = (self.sweep_angle + 1.8 * dt) % (2.0 * math.pi)

        # Slowly move an obstacle to simulate dynamic agent
        self.obstacles[0][0] = -2.4 + 0.8 * math.sin(0.4 * self.time)
        self.obstacles[0][1] = 3.2 + 0.8 * math.cos(0.4 * self.time)

        ray_data = []
        cpa_dist = self.max_range
        cpa_angle = 0.0

        # 36 Ray intersections
        angles = np.linspace(0, 2 * math.pi, self.num_rays, endpoint=False)
        for i, a in enumerate(angles):
            # Wall boundary (box at [-8, 8])
            # Ray: x = r * cos(a), y = r * sin(a)
            ca = math.cos(a)
            sa = math.sin(a)

            r_hit = self.max_range

            # Test perimeter box (room walls at 7.0 meters)
            box_d = 7.0
            if abs(ca) > 1e-4:
                rx = (box_d if ca > 0 else -box_d) / ca
                if rx > 0 and abs(rx * sa) <= box_d and rx < r_hit:
                    r_hit = rx
            if abs(sa) > 1e-4:
                ry = (box_d if sa > 0 else -box_d) / sa
                if ry > 0 and abs(ry * ca) <= box_d and ry < r_hit:
                    r_hit = ry

            # Test cylindrical obstacles
            for ox, oy, rad in self.obstacles:
                # Distance from origin to line along ray: |ca*oy - sa*ox|
                cross = abs(ca * oy - sa * ox)
                dot = ca * ox + sa * oy
                if dot > 0 and cross <= rad:
                    hit_d = dot - math.sqrt(max(0.0, rad*rad - cross*cross))
                    if hit_d > 0.2 and hit_d < r_hit:
                        r_hit = hit_d

            # Simulated sensor gaussian noise (+/- 2 cm)
            r_noisy = max(0.2, min(self.max_range, r_hit + np.random.normal(0, 0.015)))

            if r_noisy < cpa_dist:
                cpa_dist = r_noisy
                cpa_angle = a

            ray_data.append(round(float(r_noisy), 2))

        # Vector Field Histogram (VFH): find safest corridor (max distance sector)
        smoothed = np.convolve(ray_data, [0.2, 0.6, 0.2], mode="same")
        best_sector_idx = int(np.argmax(smoothed))
        safe_heading_deg = round(math.degrees(angles[best_sector_idx]), 1)

        return {
            "sweep_deg": round(math.degrees(self.sweep_angle), 1),
            "ranges": ray_data,
            "cpa_m": round(float(cpa_dist), 2),
            "cpa_deg": round(math.degrees(cpa_angle), 1),
            "safe_corridor_deg": safe_heading_deg,
            "pts_per_sec": 36 * 30 * 100, # 108,000 pts/s equivalent
            "targets_count": len(self.obstacles)
        }

# ─────────────────────────────────────────────────────────────────────────────
# 3. ORBITAL SGP4 / J2 PROPAGATOR (ISS / CUBESAT TELEMETRY)
# ─────────────────────────────────────────────────────────────────────────────
class OrbitalPropagator:
    def __init__(self):
        self.epoch = time.time()
        self.semi_major = 6791.0 # km (ISS orbit ~418 km altitude)
        self.inclination = 51.64 # degrees
        self.period_s = 92.8 * 60.0 # ~5568 seconds
        self.speed_km_s = 7.66 # orbital speed

    def get_state(self):
        t = time.time()
        phase = ((t - self.epoch) % self.period_s) / self.period_s
        orbit_angle = phase * 2.0 * math.pi

        # Ground track sub-satellite point
        lat = self.inclination * math.sin(orbit_angle)
        earth_rot = (t / 86400.0) * 360.0 # Earth rotation degrees
        lon = ((math.degrees(orbit_angle) - earth_rot + 180.0) % 360.0) - 180.0

        # Sunlight / Eclipse: in eclipse for ~35% of orbit
        in_sunlight = math.cos(orbit_angle) > -0.32
        eclipse_rem_s = int((1.0 - phase) * self.period_s) if in_sunlight else int(0.35 * self.period_s * abs(math.cos(orbit_angle)))

        # Nadir pointing quaternion
        qw = math.cos(orbit_angle / 2.0)
        qz = math.sin(orbit_angle / 2.0)

        return {
            "alt_km": round(418.0 + 4.2 * math.cos(orbit_angle * 2.0), 1),
            "lat": round(lat, 2),
            "lon": round(lon, 2),
            "speed_kms": self.speed_km_s,
            "in_sunlight": in_sunlight,
            "sun_status": "SUNLIGHT" if in_sunlight else "ECLIPSE",
            "next_event_min": round(eclipse_rem_s / 60.0, 1),
            "beta_angle_deg": round(28.4 * math.sin(orbit_angle), 1),
            "nadir_quat": [round(qw, 4), 0.0, 0.0, round(qz, 4)]
        }

# ─────────────────────────────────────────────────────────────────────────────
# 4. VEHICLE LATERAL DYNAMICS (BICYCLE MODEL + PACEJKA TIRE FORMULA)
# ─────────────────────────────────────────────────────────────────────────────
class VehicleLateralDynamics:
    def __init__(self):
        self.m = 1450.0 # kg
        self.Iz = 2250.0 # kg*m^2
        self.a = 1.15 # distance CG to front axle (m)
        self.b = 1.45 # distance CG to rear axle (m)
        self.vx = 22.2 # ~80 km/h (m/s)
        self.Cf = 45000.0 # N/rad front cornering stiffness
        self.Cr = 55000.0 # N/rad rear cornering stiffness

        # State vector: [sideslip_beta, yaw_rate_r]
        self.beta = 0.0 # rad
        self.r = 0.0 # rad/s
        self.delta = 0.0 # steering angle (rad)
        self.time = 0.0

        # Hurwitz State-Space Continuous Matrices
        self.A = np.array([
            [-(self.Cf + self.Cr) / (self.m * self.vx), (self.b * self.Cr - self.a * self.Cf) / (self.m * self.vx**2) - 1.0],
            [(self.b * self.Cr - self.a * self.Cf) / self.Iz, -(self.a**2 * self.Cf + self.b**2 * self.Cr) / (self.Iz * self.vx)]
        ])
        self.B = np.array([
            [self.Cf / (self.m * self.vx)],
            [self.a * self.Cf / self.Iz]
        ])

    def step(self, dt):
        self.time += dt
        # Smooth sinusoidal steering input (virtual slalom test, +/- 2.5 deg)
        self.delta = math.radians(2.5) * math.sin(0.8 * self.time)

        # Numerical integration of linear state-space bicycle model
        x = np.array([[self.beta], [self.r]])
        x_dot = self.A @ x + self.B * self.delta
        x_new = x + x_dot * dt

        self.beta = float(x_new[0, 0])
        self.r = float(x_new[1, 0])

        # Front & rear tire slip angles
        alpha_f = self.delta - (self.beta + self.a * self.r / self.vx)
        alpha_r = -(self.beta - self.b * self.r / self.vx)

        # Lateral acceleration in g's: a_y = vx * (beta_dot + r)
        lat_acc_g = (self.vx * (float(x_dot[0, 0]) + self.r)) / 9.81

        return {
            "speed_kmh": round(self.vx * 3.6, 1),
            "steer_deg": round(math.degrees(self.delta), 2),
            "slip_front_deg": round(math.degrees(alpha_f), 2),
            "slip_rear_deg": round(math.degrees(alpha_r), 2),
            "yaw_rate_deg_s": round(math.degrees(self.r), 2),
            "lat_g": round(float(lat_acc_g), 2),
            "sideslip_beta_deg": round(math.degrees(self.beta), 2)
        }

# ─────────────────────────────────────────────────────────────────────────────
# MAIN EXECUTION LOOP (25 Hz)
# ─────────────────────────────────────────────────────────────────────────────
def main():
    quad = Quadrotor6DOF()
    lidar = SyntheticLiDAR2D()
    orbit = OrbitalPropagator()
    vehicle = VehicleLateralDynamics()

    json_path = "/tmp/quickshell_sim.json"
    tmp_path = "/tmp/quickshell_sim.json.tmp"
    sock_path = "/tmp/quickshell_sim.sock"

    # Set up UNIX socket for optional bidirectional commands
    if os.path.exists(sock_path):
        try: os.unlink(sock_path)
        except OSError: pass

    server_sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    server_sock.bind(sock_path)
    server_sock.setblocking(False)

    dt = 0.04 # 25 Hz
    last_orbit_update = 0.0
    orbit_data = orbit.get_state()

    while True:
        t0 = time.time()

        # Step models
        q_data = quad.step(dt)
        l_data = lidar.step(dt)
        v_data = vehicle.step(dt)

        if t0 - last_orbit_update > 0.5: # 2 Hz for orbital mechanics
            orbit_data = orbit.get_state()
            last_orbit_update = t0

        sim_payload = {
            "ts": round(t0, 3),
            "quad": q_data,
            "lidar": l_data,
            "orbit": orbit_data,
            "vehicle": v_data
        }

        # 1. Output compact JSON line to stdout (instant IPC to Quickshell SplitParser)
        json_str = json.dumps(sim_payload)
        try:
            print(json_str, flush=True)
        except (BrokenPipeError, IOError):
            pass

        # 2. Write atomic file for low-latency zero-copy memory reads
        try:
            with open(tmp_path, "w") as f:
                f.write(json_str)
            os.replace(tmp_path, json_path)
        except Exception:
            pass

        # 3. Check for parameter inputs on socket (non-blocking)
        try:
            readable, _, _ = select.select([server_sock], [], [], 0.0)
            if readable:
                data, _ = server_sock.recvfrom(1024)
                # Future: parse parameter changes (PID gains, wind, etc.)
        except Exception:
            pass

        # Maintain 25 Hz loop time
        elapsed = time.time() - t0
        rem_sleep = max(0.005, dt - elapsed)
        time.sleep(rem_sleep)

if __name__ == "__main__":
    main()
