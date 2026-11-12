import React from 'react';
import {AbsoluteFill, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {CARDS, COPY, FONTS, PALETTE, SCENES} from '../config';
import {AnniversaryCard} from '../components/AnniversaryCard';
import {SoftBackdrop, gradientCss} from '../components/Gradient';
import {PhoneFrame} from '../components/PhoneFrame';
import {Subtitle} from '../components/Subtitle';
import {fadeIn} from '../utils/anim';

const SectionLabel: React.FC<{text: string; opacity: number}> = ({text, opacity}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 14, height: 42, opacity}}>
    <span style={{fontFamily: FONTS.stackCN, fontSize: 28, color: PALETTE.muted, letterSpacing: 4}}>{text}</span>
    <div style={{height: 1, flex: 1, background: PALETTE.hairline}} />
  </div>
);

/** S2 纪念日列表 4–11s：手机升起归正，4 张卡片错落入场 + 数字滚动 */
export const S2List: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const duration = SCENES.s2.duration;

  const phoneP = spring({frame, fps, config: {damping: 19, stiffness: 72, mass: 1}, durationInFrames: 78});
  const riseY = (1 - phoneP) * 520 - 70;
  const rot = (1 - phoneP) * -7;

  return (
    <AbsoluteFill>
      <SoftBackdrop frame={frame} duration={duration} tone="light" first="love" second="work" />
      <PhoneFrame containerStyle={{transform: `translateY(${riseY}px) rotate(${rot}deg)`}}>
        <div style={{padding: '22px 36px 250px'}}>
          <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 74, opacity: fadeIn(frame, 12, 20)}}>
            <span style={{fontFamily: FONTS.stackCN, fontSize: 54, fontWeight: 700, color: PALETTE.ink}}>
              {COPY.s2.appName}
            </span>
            <div style={{width: 58, height: 58, borderRadius: 20, background: gradientCss('love'), boxShadow: '0 6px 18px rgba(194,24,91,0.24)'}} />
          </div>

          <div style={{display: 'flex', alignItems: 'center', gap: 30, height: 48, opacity: fadeIn(frame, 16, 20)}}>
            <span style={{fontFamily: FONTS.stackCN, fontSize: 30, fontWeight: 700, color: PALETTE.ink}}>{COPY.s2.future}</span>
            <span style={{fontFamily: FONTS.stackCN, fontSize: 30, color: PALETTE.muted}}>{COPY.s2.past}</span>
          </div>

          <SectionLabel text={COPY.s2.future} opacity={fadeIn(frame, 22, 18)} />
          <div style={{display: 'flex', flexDirection: 'column', gap: 14}}>
            <AnniversaryCard data={CARDS[0]} frame={frame} delay={26} fps={fps} />
            <AnniversaryCard data={CARDS[1]} frame={frame} delay={38} fps={fps} />
          </div>

          <div style={{height: 12}} />
          <SectionLabel text={COPY.s2.past} opacity={fadeIn(frame, 48, 18)} />
          <div style={{display: 'flex', flexDirection: 'column', gap: 14}}>
            <AnniversaryCard data={CARDS[2]} frame={frame} delay={52} fps={fps} />
            <AnniversaryCard data={CARDS[3]} frame={frame} delay={64} fps={fps} />
          </div>
        </div>
      </PhoneFrame>
      <Subtitle text={COPY.s2.subtitle} start={30} end={196} />
    </AbsoluteFill>
  );
};
