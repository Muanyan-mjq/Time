import React from 'react';
import {AbsoluteFill, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {COPY, FONTS, PALETTE, SCENES} from '../config';
import {SoftBackdrop} from '../components/Gradient';
import {OfflineIcon, OfflineIconKind, StrikeLine} from '../components/OfflineIcons';
import {Subtitle} from '../components/Subtitle';
import {EASE_IN, fadeIn, fadeOut, rise} from '../utils/anim';

const ICONS: {kind: OfflineIconKind; label: string; x: number; y: number}[] = [
  {kind: 'cloud', label: COPY.s6.icons[0], x: 150, y: 380},
  {kind: 'account', label: COPY.s6.icons[1], x: 820, y: 380},
  {kind: 'analytics', label: COPY.s6.icons[2], x: 150, y: 1000},
  {kind: 'network', label: COPY.s6.icons[3], x: 820, y: 1000},
];

/** S6 完全离线 32–40s：情绪高点，图标克制地划掉，三条大字依次落下 */
export const S6Offline: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s6.duration;

  return (
    <AbsoluteFill style={{backgroundColor: PALETTE.dark}}>
      <SoftBackdrop frame={frame} duration={duration} tone="dark" first="love" second="work" />
      <AbsoluteFill style={{background: 'radial-gradient(circle at 50% 40%, rgba(244,143,177,0.10), rgba(18,18,18,0) 58%)'}} />

      {/* 手机轮廓 */}
      <div
        style={{
          position: 'absolute',
          left: 330,
          top: 350,
          width: 420,
          height: 820,
          borderRadius: 70,
          border: '2px solid rgba(255,255,255,0.18)',
          boxShadow: 'inset 0 0 90px rgba(255,255,255,0.035)',
          opacity: fadeIn(frame, 4, 26),
        }}
      />

      {/* 云 / 账号 / 埋点 / 网络：逐个出现 -> 划掉 -> 淡出 */}
      {ICONS.map((item, i) => {
        const appear = fadeIn(frame, 16 + i * 12, 20);
        const disappear = fadeOut(frame, 126 + i * 8, 34, EASE_IN);
        const strike = spring({
          frame: Math.max(0, frame - (104 + i * 8)),
          fps,
          config: {damping: 200, stiffness: 120},
          durationInFrames: 30,
        });
        const opacity = appear * disappear;
        return (
          <div
            key={item.kind}
            style={{
              position: 'absolute',
              left: item.x,
              top: item.y,
              width: 110,
              textAlign: 'center',
              opacity,
              transform: `scale(${1 - strike * 0.05})`,
            }}
          >
            <div style={{position: 'relative', width: 110, height: 110, margin: '0 auto'}}>
              <OfflineIcon kind={item.kind} color="rgba(255,255,255,0.72)" size={110} />
              <StrikeLine progress={strike} color="rgba(255,255,255,0.88)" size={110} />
            </div>
            <div
              style={{
                marginTop: 12,
                fontFamily: FONTS.stackCN,
                fontSize: 24,
                color: 'rgba(255,255,255,0.55)',
              }}
            >
              {item.label}
            </div>
          </div>
        );
      })}

      {/* 三条大字 */}
      {COPY.s6.lines.map((line, i) => {
        const a = rise(frame, 24 + i * 30, fps, 42, 92, 20);
        return (
          <div
            key={line}
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 536 + i * 108,
              textAlign: 'center',
              fontFamily: FONTS.stackCN,
              fontSize: 76,
              fontWeight: 700,
              color: 'rgba(255,255,255,0.97)',
              letterSpacing: 2,
              textShadow: '0 6px 40px rgba(0,0,0,0.35)',
              opacity: a.opacity,
              transform: `translateY(${a.y}px) scale(${a.scale})`,
            }}
          >
            {line}
          </div>
        );
      })}

      {/* 强调句 */}
      {(() => {
        const a = rise(frame, 148, fps, 36);
        return (
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 1200,
              textAlign: 'center',
              fontFamily: FONTS.stackCN,
              fontSize: 56,
              fontWeight: 700,
              color: '#F7C6D9',
              opacity: a.opacity,
              transform: `translateY(${a.y}px)`,
            }}
          >
            {COPY.s6.emphasis}
          </div>
        );
      })()}

      <div
        style={{
          position: 'absolute',
          left: 260,
          top: 1284,
          width: 560,
          height: 2,
          background: 'linear-gradient(90deg, rgba(244,143,177,0), rgba(244,143,177,0.8), rgba(244,143,177,0))',
          opacity: fadeIn(frame, 156, 22),
          transform: `scaleX(${fadeIn(frame, 156, 30)})`,
        }}
      />

      {(() => {
        const a = rise(frame, 172, fps, 32);
        return (
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 1310,
              textAlign: 'center',
              fontFamily: FONTS.stackCN,
              fontSize: 62,
              fontWeight: 700,
              color: '#FFFFFF',
              opacity: a.opacity,
              transform: `translateY(${a.y}px)`,
            }}
          >
            {COPY.s6.closing}
          </div>
        );
      })()}

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 1416,
          textAlign: 'center',
          fontFamily: FONTS.stackCN,
          fontSize: 30,
          color: PALETTE.muted,
          opacity: fadeIn(frame, 178, 22),
        }}
      >
        {COPY.s6.tags}
      </div>

      <Subtitle text={COPY.s6.subtitle} start={28} end={226} />
    </AbsoluteFill>
  );
};
