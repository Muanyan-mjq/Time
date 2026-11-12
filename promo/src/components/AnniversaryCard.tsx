import React from 'react';
import {CardData, FONTS, GRADIENTS, PALETTE} from '../config';
import {rise} from '../utils/anim';
import {gradientCss} from './Gradient';
import {NumberRoll} from './NumberRoll';

/** 首页纪念日卡片：大圆角、渐变封面、大号倒计时、一枚白色小徽章 */
export const AnniversaryCard: React.FC<{
  data: CardData;
  frame: number;
  delay: number;
  fps: number;
  width?: number;
}> = ({data, frame, delay, fps, width = 596}) => {
  const a = rise(frame, delay, fps, 56);
  return (
    <div
      style={{
        width,
        height: 176,
        borderRadius: 34,
        background: PALETTE.white,
        boxShadow: '0 14px 34px rgba(30,30,40,0.08)',
        border: '1px solid rgba(51,51,51,0.05)',
        display: 'flex',
        alignItems: 'center',
        gap: 22,
        padding: 20,
        position: 'relative',
        opacity: a.opacity,
        transform: `translateY(${a.y}px) scale(${a.scale})`,
      }}
    >
      <div
        style={{
          width: 136,
          height: 136,
          flexShrink: 0,
          borderRadius: 26,
          background: gradientCss(data.gradient),
          boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.4)',
        }}
      />
      <div style={{display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0}}>
        <div style={{fontFamily: FONTS.stackCN, fontSize: 38, fontWeight: 700, color: PALETTE.ink, lineHeight: 1.15}}>
          {data.title}
        </div>
        <div style={{fontFamily: FONTS.stackCN, fontSize: 24, color: PALETTE.muted, letterSpacing: 1}}>
          {data.date}
        </div>
        <div style={{display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 2}}>
          <span style={{fontFamily: FONTS.stackCN, fontSize: 26, color: PALETTE.ink}}>{data.prefix}</span>
          <NumberRoll
            value={data.days}
            frame={frame}
            delay={delay + 4}
            style={{
              fontFamily: FONTS.stackHand,
              fontSize: 62,
              lineHeight: 1,
              color: GRADIENTS[data.gradient][1],
              fontWeight: 700,
            }}
          />
          <span style={{fontFamily: FONTS.stackCN, fontSize: 26, color: PALETTE.ink}}>天</span>
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          top: 18,
          right: 18,
          padding: '6px 14px',
          borderRadius: 99,
          background: 'rgba(255,255,255,0.94)',
          color: GRADIENTS[data.gradient][1],
          fontFamily: FONTS.stackCN,
          fontSize: 20,
          fontWeight: 700,
          boxShadow: '0 3px 10px rgba(0,0,0,0.08)',
        }}
      >
        {data.badge}
      </div>
    </div>
  );
};
