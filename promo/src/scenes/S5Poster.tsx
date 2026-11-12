import React from 'react';
import {AbsoluteFill, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {COPY, PALETTE, POSTERS, SCENES} from '../config';
import {SoftBackdrop} from '../components/Gradient';
import {Poster} from '../components/Poster';
import {Subtitle} from '../components/Subtitle';
import {eased, EASE_IN_OUT, fadeIn, fadeOut} from '../utils/anim';

/** S5 分享海报 26–32s：从手机中抽出放大 -> 3D 归正 -> 左右滑动换一张 */
export const S5Poster: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s5.duration;

  const draw = spring({frame, fps, config: {damping: 20, stiffness: 62, mass: 1}, durationInFrames: 78});
  const scale = 0.44 + 0.56 * draw;
  const tilt = (1 - eased(frame, 0, 82, EASE_IN_OUT)) * -14;
  const slideP = spring({
    frame: Math.max(0, frame - 100),
    fps,
    config: {damping: 22, stiffness: 78, mass: 1},
    durationInFrames: 54,
  });
  const slide = slideP * 780;

  return (
    <AbsoluteFill>
      <SoftBackdrop frame={frame} duration={duration} tone="light" first="birthday" second="study" />

      {/* 抽出的起点：一闪而过的手机轮廓 */}
      <div
        style={{
          position: 'absolute',
          left: 340,
          top: 560,
          width: 400,
          height: 800,
          borderRadius: 64,
          border: `2px solid ${PALETTE.hairline}`,
          opacity: fadeOut(frame, 18, 40) * 0.7,
        }}
      />

      <div
        style={{
          position: 'absolute',
          left: 180,
          top: 250,
          width: 720,
          height: 1280,
          borderRadius: 44,
          overflow: 'hidden',
          boxShadow: '0 46px 120px rgba(30,16,40,0.30)',
          transformOrigin: '50% 82%',
          transform: `perspective(1700px) rotateY(${tilt}deg) scale(${scale})`,
          opacity: fadeIn(frame, 0, 16),
        }}
      >
        <div style={{display: 'flex', gap: 60, width: 1500, transform: `translateX(${-slide}px)`}}>
          {POSTERS.map((p, i) => (
            <Poster key={i} data={p} width={720} height={1280} />
          ))}
        </div>
      </div>

      {/* 页码圆点 */}
      <div style={{position: 'absolute', left: 0, right: 0, top: 1552, display: 'flex', justifyContent: 'center', gap: 14}}>
        {POSTERS.map((_, i) => (
          <div
            key={i}
            style={{
              width: 12,
              height: 12,
              borderRadius: 99,
              background: i === 0 ? PALETTE.ink : 'rgba(51,51,51,0.24)',
              opacity: i === 0 ? 1 - 0.55 * slideP : 0.45 + 0.55 * slideP,
            }}
          />
        ))}
      </div>

      <Subtitle text={COPY.s5.subtitle} start={24} end={168} />
    </AbsoluteFill>
  );
};
