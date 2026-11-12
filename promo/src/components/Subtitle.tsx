import React from 'react';
import {useCurrentFrame} from 'remotion';
import {FONTS, SUBTITLE} from '../config';
import {fadeIn, fadeOut} from '../utils/anim';

/** 统一字幕条：下沿距底 250px（> 安全区 220px），白字 + 半透明底 + 轻阴影 */
export const Subtitle: React.FC<{text: string; start: number; end: number}> = ({text, start, end}) => {
  const frame = useCurrentFrame();
  const opacity =
    fadeIn(frame, start, SUBTITLE.fadeFrames) *
    fadeOut(frame, end - SUBTITLE.fadeFrames, SUBTITLE.fadeFrames);
  if (opacity <= 0.001) return null;

  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: SUBTITLE.bottom,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          opacity,
          maxWidth: 1000,
          padding: '18px 42px 22px',
          borderRadius: 999,
          backgroundColor: 'rgba(18,18,18,0.46)',
          backdropFilter: 'blur(14px)',
          WebkitBackdropFilter: 'blur(14px)',
          boxShadow: '0 12px 40px rgba(0,0,0,0.14)',
        }}
      >
        <span
          style={{
            display: 'block',
            fontFamily: FONTS.stackCN,
            fontSize: SUBTITLE.fontSize,
            lineHeight: 1.3,
            color: '#FFFFFF',
            textAlign: 'center',
            whiteSpace: 'nowrap',
            textShadow: '0 3px 16px rgba(0,0,0,0.55)',
          }}
        >
          {text}
        </span>
      </div>
    </div>
  );
};
