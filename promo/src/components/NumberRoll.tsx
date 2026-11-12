import React from 'react';
import {useVideoConfig} from 'remotion';
import {rollNumber} from '../utils/anim';

/** spring 驱动的数字滚动，非线性 */
export const NumberRoll: React.FC<{
  value: number;
  frame: number;
  delay: number;
  style?: React.CSSProperties;
}> = ({value, frame, delay, style}) => {
  const {fps} = useVideoConfig();
  const shown = rollNumber(frame, delay, fps, value);
  return <span style={style}>{shown.toLocaleString('en-US')}</span>;
};
