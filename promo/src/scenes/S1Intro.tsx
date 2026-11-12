import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {COPY, FONTS, PALETTE, SCENES} from '../config';
import {ArcRing} from '../components/ArcRing';
import {SoftBackdrop} from '../components/Gradient';
import {fadeIn, rise} from '../utils/anim';

/** S1 开场钩子 0–4s：细弧圆环绘制 + 逐字浮现 */
export const S1Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s1.duration;
  const tagline = COPY.s1.tagline.split('');

  return (
    <AbsoluteFill style={{backgroundColor: PALETTE.dark}}>
      <SoftBackdrop frame={frame} duration={duration} tone="dark" first="love" second="study" />
      <AbsoluteFill style={{background: 'radial-gradient(circle at 50% 42%, rgba(255,255,255,0.05), rgba(18,18,18,0) 62%)'}} />

      <div style={{position: 'absolute', left: 230, top: 540, opacity: fadeIn(frame, 2, 20)}}>
        <ArcRing frame={frame} delay={4} fps={fps} size={620} stroke={4} from="#F48FB1" to="#B39DDB" />
      </div>

      <div style={{position: 'absolute', left: 0, right: 0, top: 700, textAlign: 'center'}}>
        <div
          style={{
            fontFamily: FONTS.stackHand,
            fontSize: 66,
            color: '#F48FB1',
            opacity: fadeIn(frame, 20, 22),
            letterSpacing: 3,
          }}
        >
          {COPY.s1.tiny}
        </div>
      </div>

      <div style={{position: 'absolute', left: 0, right: 0, top: 748, textAlign: 'center'}}>
        {(() => {
          const a = rise(frame, 18, fps, 34, 90, 20);
          return (
            <span
              style={{
                display: 'inline-block',
                fontFamily: FONTS.stackCN,
                fontSize: 150,
                fontWeight: 700,
                color: '#FFFFFF',
                letterSpacing: 26,
                textShadow: '0 8px 48px rgba(244,143,177,0.28)',
                opacity: a.opacity,
                transform: `translateY(${a.y}px) scale(${a.scale})`,
              }}
            >
              {COPY.s1.wordmark}
            </span>
          );
        })()}
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 1210,
          display: 'flex',
          justifyContent: 'center',
          gap: 4,
        }}
      >
        {tagline.map((ch, i) => {
          const a = rise(frame, 48 + i * 4, fps, 24, 120, 20);
          return (
            <span
              key={i}
              style={{
                display: 'inline-block',
                fontFamily: FONTS.stackCN,
                fontSize: 54,
                color: 'rgba(255,255,255,0.90)',
                letterSpacing: 2,
                opacity: a.opacity,
                transform: `translateY(${a.y}px)`,
              }}
            >
              {ch === ' ' ? '\u00a0' : ch}
            </span>
          );
        })}
      </div>

      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: 1338,
          width: 120,
          height: 2,
          marginLeft: -60,
          background: 'linear-gradient(90deg, rgba(244,143,177,0), rgba(244,143,177,0.9), rgba(244,143,177,0))',
          opacity: fadeIn(frame, 82, 22) * 0.8,
          transform: `scaleX(${fadeIn(frame, 82, 30)})`,
        }}
      />
    </AbsoluteFill>
  );
};
