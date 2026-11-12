import React from 'react';
import {Img, staticFile} from 'remotion';
import {ASSETS, COPY, FONTS, PosterData} from '../config';
import {gradientCss} from './Gradient';

/** 1080×1920 分享海报（满幅渐变 + 标题 + 日期 + 天数 + 右下角二维码） */
export const Poster: React.FC<{data: PosterData; width: number; height: number}> = ({data, width, height}) => (
  <div
    style={{
      width,
      height,
      position: 'relative',
      overflow: 'hidden',
      borderRadius: 44,
      background: gradientCss(data.gradient, 150),
      boxShadow: '0 42px 110px rgba(20,10,30,0.32)',
    }}
  >
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: 'radial-gradient(circle at 24% 14%, rgba(255,255,255,0.30) 0%, rgba(255,255,255,0) 58%)',
      }}
    />
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: 'linear-gradient(180deg, rgba(0,0,0,0.02) 0%, rgba(0,0,0,0) 42%, rgba(0,0,0,0.34) 100%)',
      }}
    />

    <div style={{position: 'absolute', top: 58, left: 58, right: 58, display: 'flex', justifyContent: 'space-between'}}>
      <span style={{fontFamily: FONTS.stackHand, fontSize: 38, color: '#FFFFFF', letterSpacing: 2}}>
        {COPY.s5.posterWordmark}
      </span>
      <span style={{fontFamily: FONTS.stackCN, fontSize: 26, color: 'rgba(255,255,255,0.82)'}}>1080 × 1920</span>
    </div>

    <div style={{position: 'absolute', left: 58, right: 58, bottom: 250, display: 'flex', flexDirection: 'column', gap: 10}}>
      <div style={{fontFamily: FONTS.stackCN, fontSize: 40, color: 'rgba(255,255,255,0.92)', letterSpacing: 4}}>
        {data.date}
      </div>
      <div style={{fontFamily: FONTS.stackCN, fontSize: 88, fontWeight: 700, color: '#FFFFFF', lineHeight: 1.15}}>
        {data.title}
      </div>
      <div style={{display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 12}}>
        <span style={{fontFamily: FONTS.stackCN, fontSize: 34, color: '#FFFFFF'}}>{data.prefix}</span>
        <span style={{fontFamily: FONTS.stackHand, fontSize: 150, lineHeight: 1, color: '#FFFFFF', fontWeight: 700}}>
          {data.days.toLocaleString('en-US')}
        </span>
        <span style={{fontFamily: FONTS.stackCN, fontSize: 34, color: '#FFFFFF'}}>天</span>
      </div>
    </div>

    <div style={{position: 'absolute', left: 58, bottom: 62, fontFamily: FONTS.stackCN, fontSize: 28, color: 'rgba(255,255,255,0.86)'}}>
      记录每一个值得记住的日子
    </div>

    <div
      style={{
        position: 'absolute',
        right: 58,
        bottom: 62,
        width: 156,
        height: 156,
        borderRadius: 20,
        background: '#FFFFFF',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxShadow: '0 10px 30px rgba(0,0,0,0.18)',
      }}
    >
      <Img src={staticFile(ASSETS.qr)} style={{width: 132, height: 132}} />
    </div>
  </div>
);
