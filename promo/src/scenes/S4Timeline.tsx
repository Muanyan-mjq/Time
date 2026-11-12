import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {COPY, FONTS, GRADIENTS, PALETTE, SCENES} from '../config';
import {SoftBackdrop, gradientCss} from '../components/Gradient';
import {PhoneFrame} from '../components/PhoneFrame';
import {Subtitle} from '../components/Subtitle';
import {fadeIn, rise, scrollProgress} from '../utils/anim';

type Row = (typeof COPY.s4.items)[number];

const TimelineRow: React.FC<{item: Row; y: number; frame: number; fps: number; delay: number}> = ({
  item,
  y,
  frame,
  fps,
  delay,
}) => {
  const a = rise(frame, delay, fps, 46);
  return (
    <div style={{position: 'absolute', top: y, left: 0, right: 0, opacity: a.opacity, transform: `translateY(${a.y}px)`}}>
      <div
        style={{
          position: 'absolute',
          left: 62,
          top: 66,
          width: 16,
          height: 16,
          borderRadius: 99,
          background: PALETTE.white,
          border: `4px solid ${GRADIENTS[item.gradient][1]}`,
        }}
      />
      <div
        style={{
          marginLeft: 110,
          width: 486,
          height: 146,
          borderRadius: 28,
          background: PALETTE.white,
          boxShadow: '0 12px 28px rgba(30,30,40,0.08)',
          display: 'flex',
          alignItems: 'center',
          gap: 18,
          padding: 16,
        }}
      >
        <div style={{width: 88, height: 88, borderRadius: 20, flexShrink: 0, background: gradientCss(item.gradient)}} />
        <div style={{display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0}}>
          <div style={{fontFamily: FONTS.stackCN, fontSize: 32, fontWeight: 700, color: PALETTE.ink}}>{item.title}</div>
          <div style={{fontFamily: FONTS.stackCN, fontSize: 22, color: PALETTE.muted, letterSpacing: 2}}>{item.date}</div>
          <div style={{fontFamily: FONTS.stackCN, fontSize: 26, color: GRADIENTS[item.gradient][1], whiteSpace: 'nowrap'}}>
            {item.days}
          </div>
        </div>
      </div>
    </div>
  );
};

/** S4 时光轴 18–26s：竖轴 + 今天横标 + 年份分节 + 时间尺高亮随滚动 */
export const S4Timeline: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s4.duration;
  const scroll = scrollProgress(frame, 16, 218);
  const offsetY = 96 - scroll * 150;
  const rulerX = scroll * 78;

  return (
    <AbsoluteFill>
      <SoftBackdrop frame={frame} duration={duration} tone="light" first="friend" second="study" />
      <PhoneFrame containerStyle={{transform: 'translateY(-70px)'}}>
        <div style={{padding: '24px 28px 0', height: '100%', overflow: 'hidden'}}>
          <div style={{display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', opacity: fadeIn(frame, 8, 20)}}>
            <span style={{fontFamily: FONTS.stackCN, fontSize: 48, fontWeight: 700, color: PALETTE.ink}}>
              {COPY.s4.appName}
            </span>
            <span style={{fontFamily: FONTS.stackCN, fontSize: 24, color: PALETTE.muted}}>{COPY.s4.rulerLabel}</span>
          </div>

          {/* 时间尺 */}
          <div style={{position: 'relative', height: 76, marginTop: 18}}>
            <div style={{position: 'absolute', left: 0, right: 0, top: 30, height: 3, borderRadius: 2, background: 'rgba(51,51,51,0.13)'}} />
            {[0, 1, 2, 3, 4, 5, 6, 7].map((i) => (
              <div
                key={i}
                style={{
                  position: 'absolute',
                  left: `${6 + i * 12}%`,
                  top: i % 2 === 0 ? 18 : 24,
                  width: 8,
                  height: 8,
                  borderRadius: 99,
                  background: i % 2 === 0 ? 'rgba(51,51,51,0.36)' : 'rgba(51,51,51,0.20)',
                }}
              />
            ))}
            <div
              style={{
                position: 'absolute',
                left: `${rulerX}%`,
                top: 18,
                width: 108,
                height: 28,
                borderRadius: 14,
                background: 'rgba(194,24,91,0.14)',
                border: '1px solid rgba(194,24,91,0.34)',
              }}
            />
            <div
              style={{
                position: 'absolute',
                left: `${rulerX}%`,
                top: 52,
                width: 108,
                textAlign: 'center',
                fontFamily: FONTS.stackCN,
                fontSize: 20,
                color: GRADIENTS.love[1],
              }}
            >
              {COPY.s4.today}
            </div>
          </div>

          {/* 年份分节标题 */}
          <div style={{display: 'flex', alignItems: 'center', gap: 16, marginTop: 10, opacity: fadeIn(frame, 18, 20)}}>
            <span style={{fontFamily: FONTS.stackCN, fontSize: 38, fontWeight: 700, color: PALETTE.ink, letterSpacing: 4}}>
              {COPY.s4.year}
            </span>
            <div style={{height: 1, flex: 1, background: PALETTE.hairline}} />
          </div>

          <div style={{position: 'relative', height: 900, marginTop: 18, overflow: 'hidden'}}>
            <div style={{position: 'absolute', inset: 0, transform: `translateY(${offsetY}px)`}}>
              {/* 2px 竖轴 */}
              <div style={{position: 'absolute', left: 69, top: 0, width: 2, height: 900, background: 'rgba(51,51,51,0.22)'}} />

              {/* 今天横标（居中） */}
              <div style={{position: 'absolute', top: 430, left: 69, right: 0, height: 2, background: 'rgba(194,24,91,0.55)'}} />
              <div
                style={{
                  position: 'absolute',
                  top: 404,
                  left: 100,
                  padding: '6px 20px',
                  borderRadius: 99,
                  background: GRADIENTS.love[1],
                  color: '#FFFFFF',
                  fontFamily: FONTS.stackCN,
                  fontSize: 24,
                  fontWeight: 700,
                }}
              >
                {COPY.s4.today}
              </div>

              <TimelineRow item={COPY.s4.items[0]} y={70} frame={frame} fps={fps} delay={24} />
              <TimelineRow item={COPY.s4.items[1]} y={252} frame={frame} fps={fps} delay={38} />
              <TimelineRow item={COPY.s4.items[2]} y={520} frame={frame} fps={fps} delay={54} />
              <TimelineRow item={COPY.s4.items[3]} y={702} frame={frame} fps={fps} delay={70} />
            </div>
          </div>
        </div>
      </PhoneFrame>
      <Subtitle text={COPY.s4.subtitle} start={26} end={226} />
    </AbsoluteFill>
  );
};
