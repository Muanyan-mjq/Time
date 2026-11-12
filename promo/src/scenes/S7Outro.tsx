import React, {useState} from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {ASSETS, COPY, FONTS, PALETTE, SCENES} from '../config';
import {ArcRing} from '../components/ArcRing';
import {SoftBackdrop} from '../components/Gradient';
import {eased, EASE_IN, fadeIn, rise} from '../utils/anim';

/** S7 结尾 CTA 40–45s：弧线圆环 + App 图标 + 仓库二维码，最后 10 帧淡出 */
export const S7Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s7.duration;
  const [iconFailed, setIconFailed] = useState(false);
  const [qrFailed, setQrFailed] = useState(false);

  return (
    <AbsoluteFill style={{backgroundColor: PALETTE.dark}}>
      <SoftBackdrop frame={frame} duration={duration} tone="dark" first="love" second="study" />

      <div style={{position: 'absolute', left: 260, top: 340}}>
        <ArcRing frame={frame} delay={0} fps={fps} size={560} stroke={4} from="#F48FB1" to="#B39DDB" />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 430,
          top: 510,
          width: 220,
          height: 220,
          borderRadius: 50,
          overflow: 'hidden',
          boxShadow: '0 20px 60px rgba(0,0,0,0.35)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'rgba(255,255,255,0.08)',
          opacity: fadeIn(frame, 8, 20),
        }}
      >
        {iconFailed ? (
          <span style={{fontFamily: FONTS.stackCN, fontSize: 72, fontWeight: 700, color: '#FFFFFF'}}>
            {COPY.s7.fallbackWordmark}
          </span>
        ) : (
          <Img
            src={staticFile(ASSETS.appIcon)}
            onError={() => setIconFailed(true)}
            style={{width: 220, height: 220, objectFit: 'cover'}}
          />
        )}
      </div>

      {(() => {
        const a = rise(frame, 14, fps, 30);
        return (
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 892,
              textAlign: 'center',
              fontFamily: FONTS.stackCN,
              fontSize: 78,
              fontWeight: 700,
              color: '#FFFFFF',
              letterSpacing: 3,
              opacity: a.opacity,
              transform: `translateY(${a.y}px)`,
            }}
          >
            {COPY.s7.title}
          </div>
        );
      })()}

      <div style={{position: 'absolute', left: 0, right: 0, top: 1000, textAlign: 'center', fontFamily: FONTS.stackCN, fontSize: 42, color: 'rgba(255,255,255,0.86)', opacity: fadeIn(frame, 26, 20)}}>
        {COPY.s7.sub}
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: 1072, textAlign: 'center', fontFamily: FONTS.stackCN, fontSize: 32, color: PALETTE.muted, opacity: fadeIn(frame, 34, 20), letterSpacing: 2}}>
        {COPY.s7.info}
      </div>

      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 1160,
          textAlign: 'center',
          fontFamily: FONTS.stackCN,
          fontSize: 38,
          lineHeight: 1.55,
          color: '#FFFFFF',
          opacity: fadeIn(frame, 44, 22),
        }}
      >
        <div>{COPY.s7.cta}</div>
        <div>{COPY.s7.cta2}</div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 435,
          top: 1320,
          width: 210,
          height: 210,
          borderRadius: 24,
          background: '#FFFFFF',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 14px 40px rgba(0,0,0,0.28)',
          opacity: fadeIn(frame, 56, 22),
        }}
      >
        {qrFailed ? (
          <span style={{fontFamily: FONTS.stackCN, fontSize: 20, color: PALETTE.ink, textAlign: 'center'}}>
            github.com
            <br />
            Muanyan-mjq/Time
          </span>
        ) : (
          <Img src={staticFile(ASSETS.qr)} onError={() => setQrFailed(true)} style={{width: 182, height: 182}} />
        )}
      </div>

      <div style={{position: 'absolute', left: 0, right: 0, top: 1548, textAlign: 'center', fontFamily: FONTS.stackCN, fontSize: 24, color: PALETTE.muted, opacity: fadeIn(frame, 64, 20)}}>
        扫码打开仓库
      </div>

      {/* 最后 10 帧淡出到纯色 */}
      <AbsoluteFill
        style={{
          backgroundColor: PALETTE.dark,
          opacity: eased(frame, duration - 10, duration, EASE_IN),
          pointerEvents: 'none',
        }}
      />
    </AbsoluteFill>
  );
};
