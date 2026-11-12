import {loadFont} from '@remotion/fonts';
import {staticFile} from 'remotion';
import {ASSETS, FONTS} from './config';

let pending: Promise<void> | null = null;

/**
 * 用 @remotion/fonts 加载仓库自带字体。
 * 若文件缺失/损坏，不抛错也不中断渲染：组件会回退到 CSS 字体栈。
 */
export const ensureFonts = (): Promise<void> => {
  if (pending) return pending;
  pending = (async () => {
    await Promise.all([
      loadFont({
        family: FONTS.cn,
        url: staticFile(ASSETS.fontCN),
        format: 'opentype',
        weight: '400',
        display: 'block',
      }).catch((e) => console.warn('[Time] 中文字体加载失败，使用回退字体栈', e)),
      loadFont({
        family: FONTS.hand,
        url: staticFile(ASSETS.fontHand),
        format: 'truetype',
        weight: '400',
        display: 'block',
      }).catch((e) => console.warn('[Time] 手写体加载失败，使用回退字体栈', e)),
    ]);
    if (typeof document !== 'undefined' && document.fonts) {
      await document.fonts.ready;
    }
  })();
  return pending;
};
