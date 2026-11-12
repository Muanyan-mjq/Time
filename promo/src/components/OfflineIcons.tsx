import React from 'react';

export type OfflineIconKind = 'cloud' | 'account' | 'analytics' | 'network';

/** 全部为内联 SVG 自绘，不使用任何第三方 Logo / 图标素材 */
export const OfflineIcon: React.FC<{kind: OfflineIconKind; color: string; size?: number}> = ({
  kind,
  color,
  size = 100,
}) => {
  const common = {
    fill: 'none',
    stroke: color,
    strokeWidth: 4,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 100 100">
      <g {...common}>
        {kind === 'cloud' && <path d="M27 70a16 16 0 0 1 1-32 23 23 0 0 1 44-2 17 17 0 0 1 2 34H27Z" />}
        {kind === 'account' && (
          <>
            <circle cx="50" cy="34" r="15" />
            <path d="M22 79c3-17 14-25 28-25s25 8 28 25" />
          </>
        )}
        {kind === 'analytics' && (
          <>
            <path d="M20 80h60" />
            <rect x="27" y="54" width="11" height="26" rx="3" />
            <rect x="45" y="42" width="11" height="38" rx="3" />
            <rect x="63" y="30" width="11" height="50" rx="3" />
            <path d="M28 42l18-14 16 8 14-18" opacity="0.75" />
          </>
        )}
        {kind === 'network' && (
          <>
            <circle cx="50" cy="50" r="31" />
            <path d="M19 50h62" />
            <ellipse cx="50" cy="50" rx="14" ry="31" />
            <path d="M28 30c6 5 9 12 9 20s-3 15-9 20M72 30c-6 5-9 12-9 20s3 15 9 20" opacity="0.7" />
          </>
        )}
      </g>
    </svg>
  );
};

/** 划掉的细线，spring 绘制；克制，不做碎裂/频闪 */
export const StrikeLine: React.FC<{progress: number; color: string; size?: number}> = ({
  progress,
  color,
  size = 100,
}) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 100 100"
    style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}
  >
    <line
      x1="14"
      y1="14"
      x2="86"
      y2="86"
      stroke={color}
      strokeWidth={4}
      strokeLinecap="round"
      strokeDasharray={102}
      strokeDashoffset={102 * (1 - Math.max(0, Math.min(1, progress)))}
    />
  </svg>
);
