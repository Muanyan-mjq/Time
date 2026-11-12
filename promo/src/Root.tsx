import React from 'react';
import {Composition} from 'remotion';
import {VIDEO} from './config';
import {TimePromo} from './TimePromo';

export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="TimePromo"
      component={TimePromo}
      durationInFrames={VIDEO.durationInFrames}
      fps={VIDEO.fps}
      width={VIDEO.width}
      height={VIDEO.height}
    />
  </>
);
