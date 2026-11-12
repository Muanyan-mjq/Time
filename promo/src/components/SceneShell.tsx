import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {TRANSITION_FRAMES} from '../config';
import {EASE_IN_OUT, fadeIn, fadeOut} from '../utils/anim';

/**
 * 场景外壳：统一的交叉溶解 + 镜头轻微推拉。
 * Sequence 的 durationInFrames = duration + overlap，
 * 于是相邻场景在 [duration, duration+overlap) 这段里一进一出。
 */
export const SceneShell: React.FC<{
  duration: number;
  overlap: number;
  bg: string;
  scaleFrom: number;
  scaleTo: number;
  children: React.ReactNode;
}> = ({duration, overlap, bg, scaleFrom, scaleTo, children}) => {
  const frame = useCurrentFrame();
  const enter = fadeIn(frame, 0, TRANSITION_FRAMES);
  const leave = overlap > 0 ? fadeOut(frame, duration, overlap) : 1;
  const opacity = enter * leave;
  const total = Math.max(1, duration + overlap);
  const scale = interpolate(frame, [0, total], [scaleFrom, scaleTo], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_IN_OUT,
  });

  return (
    <AbsoluteFill style={{backgroundColor: bg, opacity}}>
      <AbsoluteFill style={{transform: `scale(${scale})`}}>{children}</AbsoluteFill>
    </AbsoluteFill>
  );
};
