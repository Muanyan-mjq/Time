import React, {useEffect, useState} from 'react';
import {continueRender, delayRender} from 'remotion';
import {ensureFonts} from '../fonts';

/**
 * delayRender / continueRender：等两款字体真正加载完再截图，
 * 保证 1350 帧里中文不缺字、不闪烁。
 */
export const FontGate: React.FC<{children: React.ReactNode}> = ({children}) => {
  const [handle] = useState(() => delayRender('Loading Time fonts'));
  const [ready, setReady] = useState(false);

  useEffect(() => {
    ensureFonts().then(() => {
      setReady(true);
      continueRender(handle);
    });
  }, [handle]);

  if (!ready) return null;
  return <>{children}</>;
};
