import React from 'react';
import {AbsoluteFill} from 'remotion';
import {FONTS, PALETTE} from '../config';

export const PHONE = {
  width: 700,
  height: 1360,
  radius: 78,
  padding: 14,
  screenRadius: 64,
  statusBar: 64,
} as const;

/** 用 React/CSS 重绘的手机外框（不使用任何真实截图） */
export const PhoneFrame: React.FC<{
  children: React.ReactNode;
  theme?: 'light' | 'dark';
  containerStyle?: React.CSSProperties;
  statusTime?: string;
}> = ({children, theme = 'light', containerStyle, statusTime = '9:41'}) => {
  const fg = theme === 'light' ? PALETTE.ink : '#EDEDED';
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', ...containerStyle}}>
      <div
        style={{
          width: PHONE.width,
          height: PHONE.height,
          borderRadius: PHONE.radius,
          padding: PHONE.padding,
          background: 'linear-gradient(145deg,#4a4a52 0%,#17171c 100%)',
          boxShadow: '0 40px 110px rgba(0,0,0,0.26), inset 0 0 0 2px rgba(255,255,255,0.16)',
        }}
      >
        <div
          style={{
            position: 'relative',
            width: '100%',
            height: '100%',
            borderRadius: PHONE.screenRadius,
            background: theme === 'light' ? PALETTE.light : PALETTE.darkAlt,
            border: '2px solid rgba(255,255,255,0.10)',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              height: PHONE.statusBar,
              padding: '0 34px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              color: fg,
              fontFamily: FONTS.stackCN,
              fontSize: 24,
              fontWeight: 700,
            }}
          >
            <span>{statusTime}</span>
            <div style={{display: 'flex', alignItems: 'flex-end', gap: 5, height: 20}}>
              {[7, 11, 15, 19].map((h, i) => (
                <div key={i} style={{width: 5, height: h, borderRadius: 2, background: fg, opacity: 0.85}} />
              ))}
              <div
                style={{
                  width: 34,
                  height: 18,
                  marginLeft: 8,
                  border: `2px solid ${fg}`,
                  borderRadius: 5,
                  position: 'relative',
                  opacity: 0.85,
                }}
              >
                <div style={{position: 'absolute', inset: 3, width: '58%', background: fg, borderRadius: 2}} />
              </div>
            </div>
          </div>

          <div style={{position: 'absolute', top: PHONE.statusBar, left: 0, right: 0, bottom: 0}}>
            {children}
          </div>

          <div
            style={{
              position: 'absolute',
              bottom: 16,
              left: '50%',
              transform: 'translateX(-50%)',
              width: 180,
              height: 7,
              borderRadius: 99,
              background: fg,
              opacity: 0.28,
            }}
          />
        </div>
      </div>
    </AbsoluteFill>
  );
};
