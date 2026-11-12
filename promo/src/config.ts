/**
 * Time · 时光 宣传片 —— 所有文案、配色、时长、素材路径的唯一真值来源。
 * 改文案 / 改颜色 / 改节奏，只需要动这一个文件。
 */

export const VIDEO = {
  width: 1080,
  height: 1920,
  fps: 30,
  durationInFrames: 1350, // 45s @30fps
} as const;

/** 平台安全区：这两条线以内不放关键信息 */
export const SAFE = {
  top: 150,
  bottom: 220,
} as const;

/** 字幕条：bottom 为「字幕条下沿距画面底部」的距离，>= SAFE.bottom */
export const SUBTITLE = {
  bottom: 250,
  fontSize: 48,
  minHoldFrames: 45, // 1.5s
  fadeFrames: 16,
} as const;

export const PALETTE = {
  light: '#F5F5F5',
  lightAlt: '#EDEDED',
  dark: '#121212',
  darkAlt: '#1E1E1E',
  ink: '#333333',
  muted: '#9A9A9F',
  white: '#FFFFFF',
  hairline: 'rgba(51,51,51,0.10)',
  darkHairline: 'rgba(255,255,255,0.12)',
} as const;

/** 6 套内置渐变，与 lib/data/cover_palette.dart 完全一致 */
export const GRADIENTS = {
  love: ['#F48FB1', '#C2185B'], // 恋爱
  family: ['#FFCC80', '#E65100'], // 家人
  friend: ['#80CBC4', '#00695C'], // 朋友
  work: ['#90CAF9', '#1565C0'], // 工作
  study: ['#B39DDB', '#4527A0'], // 学习
  birthday: ['#FFAB91', '#BF360C'], // 生日
} as const;

export type GradientKey = keyof typeof GRADIENTS;

/** 场景时间表（帧号，30fps）。overlap 用于相邻场景交叉溶解 */
export const TRANSITION_FRAMES = 18;

export const SCENES = {
  s1: {from: 0, duration: 120, bg: PALETTE.dark, overlap: TRANSITION_FRAMES, scaleFrom: 1.035, scaleTo: 1.0},
  s2: {from: 120, duration: 210, bg: PALETTE.lightAlt, overlap: TRANSITION_FRAMES, scaleFrom: 1.0, scaleTo: 1.045},
  s3: {from: 330, duration: 210, bg: PALETTE.light, overlap: TRANSITION_FRAMES, scaleFrom: 1.045, scaleTo: 1.0},
  s4: {from: 540, duration: 240, bg: PALETTE.lightAlt, overlap: TRANSITION_FRAMES, scaleFrom: 1.0, scaleTo: 1.035},
  s5: {from: 780, duration: 180, bg: '#F7F2EE', overlap: TRANSITION_FRAMES, scaleFrom: 1.035, scaleTo: 1.0},
  s6: {from: 960, duration: 240, bg: PALETTE.dark, overlap: TRANSITION_FRAMES, scaleFrom: 1.0, scaleTo: 1.06},
  s7: {from: 1200, duration: 150, bg: PALETTE.dark, overlap: 0, scaleFrom: 1.0, scaleTo: 1.0},
} as const;

export const FONTS = {
  cn: 'DongQingHeiTi',
  hand: 'ConspiredLovers',
  stackCN: '"DongQingHeiTi","Noto Sans SC","Microsoft YaHei",sans-serif',
  stackHand: '"ConspiredLovers","DongQingHeiTi",cursive',
} as const;

/** BGM：无版权 -> 仓库自带脚本合成的原创氛围音；没有则把 enabled 设为 false 保持静音 */
export const BGM = {
  enabled: true,
  src: 'audio/ambient.mp3',
  volume: 0.2,
  fadeFrames: 45,
} as const;

export const REPO_URL = 'https://github.com/Muanyan-mjq/Time';

export const ASSETS = {
  qr: 'qr.png',
  appIcon: 'images/app.png',
  fontCN: 'fonts/DongQingHeiTi.otf',
  fontHand: 'fonts/conspired-lovers.woff.ttf',
} as const;

/** 首页 4 张卡片（日期按 2026-11-12 与天数反推，数字与日期自洽） */
export const CARDS = [
  {title: '在一起', date: '2027.03.20', days: 128, prefix: '还有', gradient: 'love', badge: '每年', past: false},
  {title: '妈妈生日', date: '2026.12.18', days: 36, prefix: '还有', gradient: 'birthday', badge: '每年', past: false},
  {title: '入职纪念', date: '2023.11.12', days: 1096, prefix: '已经', gradient: 'work', badge: '不重复', past: true},
  {title: '毕业', date: '2020.04.06', days: 2411, prefix: '已经', gradient: 'study', badge: '不重复', past: true},
] as const satisfies ReadonlyArray<CardData>;

export type CardData = {
  title: string;
  date: string;
  days: number;
  prefix: '还有' | '已经';
  gradient: GradientKey;
  badge: string;
  past: boolean;
};

/** 分享海报两页 */
export const POSTERS = [
  {title: '在一起', date: '2027 · 03 · 20', days: 128, prefix: '还有', gradient: 'love'},
  {title: '毕业', date: '2020 · 04 · 06', days: 2411, prefix: '已经', gradient: 'study'},
] as const satisfies ReadonlyArray<PosterData>;

export type PosterData = {
  title: string;
  date: string;
  days: number;
  prefix: '还有' | '已经';
  gradient: GradientKey;
};

/** 全部文案 */
export const COPY = {
  s1: {
    wordmark: '时光',
    tagline: '有些日子，值得被记住',
    tiny: 'Time',
  },
  s2: {
    appName: '时光',
    future: '未来',
    past: '已过去',
    subtitle: '还有多久，已经多久，一眼就知道',
  },
  s3: {
    cardTitle: '妈妈生日',
    frontLabel: '自起始日',
    frontValue: '1,096',
    frontUnit: '天',
    backLabel: '距下一次',
    backValue: '36',
    backUnit: '天',
    repeatTag: '每年重复 · 提前 3 天 · 09:00 准时提醒',
    notificationApp: '时光 · 提醒',
    notificationTitle: '明天是 妈妈生日 🎂',
    notificationBody: '提前 3 天，09:00 准时提醒',
    subtitle: '每年重复，准时提醒，重启手机也不会漏',
  },
  s4: {
    appName: '时光轴',
    today: '今天',
    year: '2027 · 3',
    rulerLabel: '时间尺',
    items: [
      {title: '在一起', date: '03.20', days: '还有 128 天', gradient: 'love'},
      {title: '妈妈生日', date: '12.18', days: '还有 36 天', gradient: 'birthday'},
      {title: '入职纪念', date: '11.12', days: '已经 1,096 天', gradient: 'work'},
      {title: '毕业', date: '04.06', days: '已经 2,411 天', gradient: 'study'},
    ] as const,
    subtitle: '过去与未来，串成一条时间线',
  },
  s5: {
    posterWordmark: 'Time · 时光',
    subtitle: '一键生成海报，分享这一天',
  },
  s6: {
    lines: ['没有账号', '没有云同步', '没有任何网络请求'],
    icons: ['云', '账号', '埋点', '网络'],
    emphasis: '连 INTERNET 权限都不申请',
    closing: '你的时光，只在你的手机里',
    tags: '备份导出 zip · 隐私锁 · 亮 / 暗主题',
    subtitle: '不收集 · 不上传 · 不联网',
  },
  s7: {
    title: 'Time · 时光',
    sub: '完全离线的纪念日 App',
    info: 'Android 7.0+ · 开源免费 · MIT',
    cta: 'GitHub 搜索 Muanyan-mjq/Time',
    cta2: 'Releases 下载 APK',
    fallbackWordmark: '时光',
  },
} as const;
