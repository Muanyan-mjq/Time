import React from 'react';
import {AbsoluteFill} from 'remotion';
import {GRADIENTS, GradientKey} from '../config';
import {eased, EASE_IN_OUT} from '../utils/anim';

export const gradientCss = (key: GradientKey, angle = 135) =>
  `linear-gradient(${angle}deg, ${GRADIENTS[key][0]} 0%, ${GRADIENTS[key][1]} 100%)`;

export const GradientSurface: React.FC<{
  gradient: GradientKey;
  angle?: number;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}> = ({gradient, angle, style, children}) => (
  <div style={{background: gradientCss(gradient, angle), ...style}}>{children}</div>
);

/** 柔和的环境光斑：镜头视差的载体，克制、不抢主体 */
export const SoftBackdrop: React.FC<{
  frame: number;
  duration: number;
  tone: 'light' | 'dark';
  first: GradientKey;
  second: GradientKey;
}> = ({frame, duration, tone, first, second}) => {
  const p = eased(frame, 0, duration, EASE_IN_OUT);
  return (
    <AbsoluteFill style={{overflow: 'hidden', opacity: tone === 'light' ? 0.5 : 0.42}}>
      <div
        style={{
          position: 'absolute',
          width: 1050,
          height: 1050,
          left: -360 + p * 90,
          top: -260 - p * 130,
          borderRadius: '50%',
          background: `radial-gradient(circle at 50% 50%, ${GRADIENTS[first][0]}66 0%, ${GRADIENTS[first][0]}00 68%)`,
          filter: 'blur(70px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 980,
          height: 980,
          right: -380 - p * 110,
          bottom: -300 + p * 150,
          borderRadius: '50%',
          background: `radial-gradient(circle at 50% 50%, ${GRADIENTS[second][1]}55 0%, ${GRADIENTS[second][1]}00 70%)`,
          filter: 'blur(80px)',
        }}
      />
    </AbsoluteFill>
  );
};
