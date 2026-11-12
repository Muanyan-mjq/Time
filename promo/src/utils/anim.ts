import {Easing, interpolate, spring} from 'remotion';

/** 统一缓动曲线：全片只用这两条 + spring，没有线性运动 */
export const EASE_OUT = Easing.bezier(0.22, 1, 0.36, 1);
export const EASE_IN = Easing.bezier(0.55, 0, 0.85, 0.35);
export const EASE_IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);

const opts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

export const fadeIn = (frame: number, start: number, duration = 18, easing: (n: number) => number = EASE_OUT) =>
  interpolate(frame, [start, start + duration], [0, 1], {...opts, easing});

export const fadeOut = (frame: number, start: number, duration = 18, easing: (n: number) => number = EASE_IN) =>
  interpolate(frame, [start, start + duration], [1, 0], {...opts, easing});

export const eased = (
  frame: number,
  start: number,
  end: number,
  easing: (n: number) => number = EASE_IN_OUT,
) => interpolate(frame, [start, end], [0, 1], {...opts, easing});

/** 元素错落入场：spring 驱动的透明度 + 位移 + 轻微缩放 */
export const rise = (
  frame: number,
  delay: number,
  fps: number,
  distance = 52,
  stiffness = 100,
  damping = 18,
) => {
  const p = spring({
    frame: Math.max(0, frame - delay),
    fps,
    config: {damping, stiffness, mass: 0.9},
    durationInFrames: 42,
  });
  return {
    opacity: Math.min(1, p),
    y: (1 - p) * distance,
    scale: 0.965 + 0.035 * p,
    progress: p,
  };
};

/** 数字滚动（非线性） */
export const rollNumber = (frame: number, delay: number, fps: number, target: number, duration = 46) => {
  const p = spring({
    frame: Math.max(0, frame - delay),
    fps,
    config: {damping: 200, stiffness: 65, mass: 1},
    durationInFrames: duration,
  });
  return Math.round(target * Math.min(1, Math.max(0, p)));
};

/** 先慢 → 再快 → 缓停（时光轴滚动），全程贝塞尔缓动，无线性段 */
export const scrollProgress = (frame: number, start: number, end: number) => {
  const t = interpolate(frame, [start, end], [0, 1], opts);
  return Easing.bezier(0.62, 0.02, 0.24, 1)(t);
};

export const clamp = (v: number, min = 0, max = 1) => Math.min(max, Math.max(min, v));
