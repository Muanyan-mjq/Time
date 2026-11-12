import React from 'react';
import {AbsoluteFill, Audio, interpolate, Sequence, staticFile} from 'remotion';
import {BGM, PALETTE, SCENES, VIDEO} from './config';
import {FontGate} from './components/FontGate';
import {SceneShell} from './components/SceneShell';
import {S1Intro} from './scenes/S1Intro';
import {S2List} from './scenes/S2List';
import {S3Repeat} from './scenes/S3Repeat';
import {S4Timeline} from './scenes/S4Timeline';
import {S5Poster} from './scenes/S5Poster';
import {S6Offline} from './scenes/S6Offline';
import {S7Outro} from './scenes/S7Outro';

const SCENE_LIST = [
  {key: 's1', Comp: S1Intro, cfg: SCENES.s1},
  {key: 's2', Comp: S2List, cfg: SCENES.s2},
  {key: 's3', Comp: S3Repeat, cfg: SCENES.s3},
  {key: 's4', Comp: S4Timeline, cfg: SCENES.s4},
  {key: 's5', Comp: S5Poster, cfg: SCENES.s5},
  {key: 's6', Comp: S6Offline, cfg: SCENES.s6},
  {key: 's7', Comp: S7Outro, cfg: SCENES.s7},
] as const;

/**
 * 七个分镜用 <Sequence> 串联；相邻场景各多留 overlap 帧做交叉溶解。
 * 全部动画由 useCurrentFrame / interpolate / spring 驱动，无 CSS transition / setTimeout。
 */
export const TimePromo: React.FC = () => (
  <FontGate>
    <AbsoluteFill style={{backgroundColor: PALETTE.dark}}>
      {SCENE_LIST.map(({key, Comp, cfg}) => (
        <Sequence key={key} from={cfg.from} durationInFrames={cfg.duration + cfg.overlap}>
          <SceneShell
            duration={cfg.duration}
            overlap={cfg.overlap}
            bg={cfg.bg}
            scaleFrom={cfg.scaleFrom}
            scaleTo={cfg.scaleTo}
          >
            <Comp />
          </SceneShell>
        </Sequence>
      ))}

      {/*
        BGM 位置（唯一音频入口）：
        - 想换音乐：把文件放到 public/audio/ 下，改 config.ts 的 BGM.src 即可。
        - 想完全静音：把 config.ts 的 BGM.enabled 设为 false。
        - 现有 ambient.mp3 是 src/scripts/make-bgm.py 用标准库合成的原创氛围音，
          不含任何第三方受版权保护的素材。
        - volume 回调在这里做首尾淡入淡出（不依赖 CSS / 定时器）。
      */}
      {BGM.enabled ? (
        <Audio
          src={staticFile(BGM.src)}
          volume={(f) =>
            interpolate(
              f,
              [0, BGM.fadeFrames, VIDEO.durationInFrames - BGM.fadeFrames, VIDEO.durationInFrames],
              [0, BGM.volume, BGM.volume, 0],
              {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
            )
          }
        />
      ) : null}
    </AbsoluteFill>
  </FontGate>
);
