import React from 'react';
import {spring} from 'remotion';

/** 自绘细弧圆环：呼应 App 的 Lottie 启动动画，spring 绘制 */
export const ArcRing: React.FC<{
  frame: number;
  delay: number;
  fps: number;
  size?: number;
  stroke?: number;
  from?: string;
  to?: string;
  trackOpacity?: number;
}> = ({
  frame,
  delay,
  fps,
  size = 620,
  stroke = 4,
  from = '#F48FB1',
  to = '#C2185B',
  trackOpacity = 0.13,
}) => {
  const gradientId = `arcring-${Math.round(size)}-${Math.round(stroke)}`;
  const p = spring({
    frame: Math.max(0, frame - delay),
    fps,
    config: {damping: 200, stiffness: 40, mass: 1},
    durationInFrames: 78,
  });
  const p2 = spring({
    frame: Math.max(0, frame - delay - 12),
    fps,
    config: {damping: 200, stiffness: 46, mass: 1},
    durationInFrames: 78,
  });
  const c = size / 2;
  const r = c - stroke * 3;
  const circumference = 2 * Math.PI * r;
  const innerR = r - 34;
  const innerC = 2 * Math.PI * innerR;

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{overflow: 'visible'}}>
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor={from} />
          <stop offset="100%" stopColor={to} />
        </linearGradient>
      </defs>
      <circle cx={c} cy={c} r={r} fill="none" stroke="#FFFFFF" strokeOpacity={trackOpacity} strokeWidth={1.5} />
      <circle
        cx={c}
        cy={c}
        r={r}
        fill="none"
        stroke={`url(#${gradientId})`}
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={circumference * (1 - Math.min(1, p))}
        transform={`rotate(-90 ${c} ${c})`}
      />
      <circle
        cx={c}
        cy={c}
        r={innerR}
        fill="none"
        stroke="#FFFFFF"
        strokeOpacity={0.22}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeDasharray={innerC}
        strokeDashoffset={innerC * (1 - Math.min(1, p2) * 0.72)}
        transform={`rotate(110 ${c} ${c})`}
      />
    </svg>
  );
};
