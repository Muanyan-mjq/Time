import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {COPY, FONTS, GRADIENTS, PALETTE, SCENES} from '../config';
import {SoftBackdrop, gradientCss} from '../components/Gradient';
import {NumberRoll} from '../components/NumberRoll';
import {PhoneFrame} from '../components/PhoneFrame';
import {Subtitle} from '../components/Subtitle';
import {eased, EASE_IN_OUT, fadeIn, rise} from '../utils/anim';

/** S3 重复与提醒 11–18s：点按翻转切换视角 + 顶部通知弹出 */
export const S3Repeat: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s3.duration;

  // 0 -> 90 -> 0 的翻转，两段都用 easing
  const flip =
    frame < 88
      ? eased(frame, 58, 88, EASE_IN_OUT) * 90
      : 90 - eased(frame, 88, 122, EASE_IN_OUT) * 90;
  const showBack = frame >= 88;
  const tag = rise(frame, 116, fps, 34);
  const note = rise(frame, 108, fps, -190);

  return (
    <AbsoluteFill>
      <SoftBackdrop frame={frame} duration={duration} tone="light" first="birthday" second="family" />
      <PhoneFrame containerStyle={{transform: 'translateY(-70px)'}}>
        <div style={{position: 'relative'}}>
          {/* 详情页顶部渐变封面 */}
          <div
            style={{
              height: 420,
              background: gradientCss('birthday'),
              borderBottomLeftRadius: 44,
              borderBottomRightRadius: 44,
              padding: '34px 40px',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
              boxShadow: '0 16px 40px rgba(191,54,12,0.20)',
            }}
          >
            <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between'}}>
              <span style={{fontFamily: FONTS.stackCN, fontSize: 40, color: '#FFFFFF'}}>‹</span>
              <div
                style={{
                  padding: '8px 18px',
                  borderRadius: 99,
                  background: 'rgba(255,255,255,0.92)',
                  fontFamily: FONTS.stackCN,
                  fontSize: 22,
                  color: GRADIENTS.birthday[1],
                  fontWeight: 700,
                }}
              >
                每年
              </div>
            </div>
            <div>
              <div style={{fontFamily: FONTS.stackCN, fontSize: 62, fontWeight: 700, color: '#FFFFFF'}}>
                {COPY.s3.cardTitle}
              </div>
              <div style={{fontFamily: FONTS.stackCN, fontSize: 30, color: 'rgba(255,255,255,0.88)', letterSpacing: 3, marginTop: 8}}>
                2026.12.18
              </div>
            </div>
          </div>

          {/* 计数切换卡片 */}
          <div style={{display: 'flex', justifyContent: 'center', marginTop: 44}}>
            <div
              style={{
                width: 560,
                height: 316,
                borderRadius: 38,
                background: PALETTE.white,
                boxShadow: '0 18px 44px rgba(30,30,40,0.10)',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 10,
                transform: `perspective(1400px) rotateY(${flip}deg)`,
                backfaceVisibility: 'hidden',
              }}
            >
              <div style={{fontFamily: FONTS.stackCN, fontSize: 32, color: PALETTE.muted, letterSpacing: 4}}>
                {showBack ? COPY.s3.backLabel : COPY.s3.frontLabel}
              </div>
              <div style={{display: 'flex', alignItems: 'baseline', gap: 12}}>
                <NumberRoll
                  value={showBack ? 36 : 1096}
                  frame={frame}
                  delay={showBack ? 88 : 18}
                  style={{
                    fontFamily: FONTS.stackHand,
                    fontSize: 132,
                    lineHeight: 1,
                    color: GRADIENTS.birthday[1],
                    fontWeight: 700,
                  }}
                />
                <span style={{fontFamily: FONTS.stackCN, fontSize: 40, color: PALETTE.ink}}>
                  {showBack ? COPY.s3.backUnit : COPY.s3.frontUnit}
                </span>
              </div>
              <div style={{fontFamily: FONTS.stackCN, fontSize: 24, color: PALETTE.muted, marginTop: 4}}>
                点按切换视角
              </div>
            </div>
          </div>

          <div
            style={{
              margin: '34px auto 0',
              width: 560,
              padding: '18px 24px',
              borderRadius: 99,
              background: 'rgba(255,255,255,0.9)',
              border: '1px solid rgba(51,51,51,0.06)',
              textAlign: 'center',
              fontFamily: FONTS.stackCN,
              fontSize: 27,
              color: PALETTE.ink,
              opacity: tag.opacity,
              transform: `translateY(${tag.y}px)`,
            }}
          >
            {COPY.s3.repeatTag}
          </div>
        </div>
      </PhoneFrame>

      {/* 通知横幅 */}
      <div
        style={{
          position: 'absolute',
          left: 190,
          top: 250,
          width: 700,
          borderRadius: 34,
          background: '#FFFFFF',
          boxShadow: '0 26px 70px rgba(0,0,0,0.22)',
          padding: '26px 30px',
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
          opacity: note.opacity,
          transform: `translateY(${note.y}px) scale(${note.scale})`,
        }}
      >
        <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
          <div style={{width: 38, height: 38, borderRadius: 12, background: gradientCss('birthday')}} />
          <span style={{fontFamily: FONTS.stackCN, fontSize: 24, color: PALETTE.muted}}>{COPY.s3.notificationApp}</span>
          <span style={{marginLeft: 'auto', fontFamily: FONTS.stackCN, fontSize: 22, color: PALETTE.muted}}>现在</span>
        </div>
        <div style={{fontFamily: FONTS.stackCN, fontSize: 38, fontWeight: 700, color: PALETTE.ink}}>
          {COPY.s3.notificationTitle}
        </div>
        <div style={{fontFamily: FONTS.stackCN, fontSize: 26, color: PALETTE.muted}}>{COPY.s3.notificationBody}</div>
      </div>

      <Subtitle text={COPY.s3.subtitle} start={26} end={196} />
    </AbsoluteFill>
  );
};
