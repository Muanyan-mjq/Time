/// 首页卡片的尺寸，2020 年定下来的视觉基线，不要动。
const double kCardRadius = 15;
const double kCardHeight = 200;
const double kCardMarginH = 30;
const double kCardMarginV = 10;

/// 首页卡片封面的解码上限（物理像素）。
///
/// 卡片铺满屏宽，1080 够 3 倍像素比的屏用；不设的话相册照片（最长边 1600）
/// 会整张进内存，一屏几张就是几十 MB。
const int kCoverDecodeWidth = 1080;

/// 列表滚动时封面层的最大视差位移（逻辑像素）。
///
/// 封面层按「比卡片本身高出两倍这么多」来画，位移时边缘才不会露出底色。
/// 12 是目测的手感上限：再多就开始像卡片在抖，而不是像有层次。
const double kParallaxMax = 12;

/// 卡片内文字的留白
const double kCardPadding = 18;

/// 列表底部给 FAB 让位
const double kListBottomInset = 96;

/// 详情页顶部大图的高度。比首页卡片高，是为了在让出状态栏 + 返回按钮的
/// 高度之后，中间那排大数字仍然有呼吸空间。
const double kDetailHeroHeight = 460;

/// 海报的逻辑画布，9:16；乘 3 倍像素比正好输出 1080×1920。
const double kPosterWidth = 360;
const double kPosterHeight = 640;
const double kPosterPixelRatio = 3.0;

/// 对话框。它是 2020 年那版的定死版式（标题 60 + 内容 100 + 按钮条 55），
/// 不是自适应的，所以这几个数只能一起改。
const double kDialogInsetH = 50;
const double kDialogHeight = 231;
const double kDialogRadius = 16;
const double kDialogTitleHeight = 60;
const double kDialogContentHeight = 100;
const double kDialogButtonHeight = 55;

/// 关于页。整页是 2020 年用绝对定位摆出来的，位置本身就是设计：
/// 右上那道紫弧、左下那团青色圆斑都在原处不动。收进来只是让它们
/// 有个名字，不是要重新排版 —— 数值和当年逐个对过。
const double kAboutBackInset = 15;
const double kAboutBackSize = 50;

/// App 图标和它下面那两行版本号。图标左边缘 48、文字左边缘 60，
/// 这 12px 的错位是原设计里手摆出来的。
const double kAboutMarkTop = 100;
const double kAboutMarkLeft = 48;
const double kAboutMarkSize = 60;
const double kAboutVersionTop = 160;
const double kAboutVersionLeft = 60;

/// 设置栏：5 行（3 个入口 + 通知栏倒计时、隐私锁两个开关）。
///
/// bottom 那个 200 是为了让设置栏落在左下角青色圆斑上方 —— 它是量着圆斑
/// 的高度给的，不是随手写的间距。开关行数只会越加越多，所以这一栏的高度
/// 交给内容自己（`mainAxisSize: min`），只钉住底边。
const double kAboutSettingsLeft = 50;
const double kAboutSettingsBottom = 200;
const double kAboutSettingsWidth = 240;

/// 设置栏的上边界，不能高过上面那两行版本号。
///
/// 版本号从 [kAboutVersionTop] 起，14 号字两行加中间那点间距大约到 207，
/// 这里再让开 13。屏幕够高时它离设置栏老远、轮不到它说话，位置仍由底边
/// 那个 200 决定；只有矮屏（比如 1080×1920 按 3 倍像素比算下来只有 640
/// 逻辑高，再减掉三键导航的 48）才会顶到这条线 —— 那一栏自己变成可滚动的，
/// 总比「功能介绍」盖在版本号上强。
const double kAboutSettingsTop = 220;

/// 开关那几行的行内图标大小与图文间距。
///
/// 上面三个图片项的尺寸不在这里 —— 那几张 png 自带的留白各不相同，
/// 36 和 30 是按各自的实际观感逐个调的，硬凑成一个数反而会歪。
const double kAboutSwitchIcon = 30;
const double kAboutRowGap = 10;

const double kAboutFooterInset = 20;

/// 右下角两行小字和上面设置栏之间的空隙
const double kAboutFooterGap = 8;

/// 页脚「隐私协议 / 软件使用协议 / 官方地址」三条链接之间的空隙
const double kAboutFooterLinkGap = 8;

/// 左上角那道弧的画布，以及左下角圆斑的画布。
///
/// 圆斑画布是个正方形，圆心取在它的底边中点上，所以绘画代码里读的是
/// `size.height` —— 改这个数，圆跟着走。
const double kAboutArcSize = 300;
const double kAboutBlobSize = 200;

/// 时光轴：左侧一条竖轴，未来在上、今天一道横标、过去在下，可以一直往下滚。
///
/// 上一版是「整条轴钉在一屏里、靠双指放大看细节」的横轴，容量有天花板，
/// 三十条以后只能靠缩放读。这一版把轴竖过来，滚动接管容量。
///
/// 每条记录是一张横着的小卡片（左封面、右文字），挂在轴的右边；年份是
/// 左对齐的分节标题。上一版那条 1px 的轴和 30px 的圆点都太弱 —— 现在轴
/// 2px、缩略图 72，一行里有东西可看。

/// 竖轴（脊椎）离页面左边的距离。
const double kTimelineAxisX = 26;

/// 轴的宽度，以及轴和右边内容之间的空当。
const double kTimelineAxisWidth = 2;
const double kTimelineCardGap = 14;

/// 卡片、年份标题、「今天」三者的左边缘。它们对齐在同一条竖线上。
const double kTimelineContentLeft = kTimelineAxisX + kTimelineCardGap;
const double kTimelineContentRight = 16;

/// 卡片左边那张封面缩略图。
const double kTimelineThumbSize = 72;
const double kTimelineThumbRadius = 12;

/// 卡片本身：圆角、四周内边距（缩略图 72 + 上下各 8 = 卡片高 88）。
const double kTimelineCardRadius = 14;
const double kTimelineCardPadding = 8;
const double kTimelineCardHeight = kTimelineThumbSize + 2 * kTimelineCardPadding;

/// 卡片之间的空隙。行高 = 卡片高 + 空隙。
///
/// 行高**必须定死**：概览带的高亮、点按跳转、「回到今天」的显隐全靠滚动
/// 位置反推行号，行高一浮动这套映射就得重来。
const double kTimelineRowGap = 12;
const double kTimelineRowHeight = kTimelineCardHeight + kTimelineRowGap;

/// 年份分节标题行，以及「今天」那道横标。
const double kTimelineYearRowHeight = 46;
const double kTimelineTodayRowHeight = 52;

/// 顶部概览带：把全部记录压成一把时间尺，看的是「一辈子摊开有多长、
/// 哪里密、现在站在哪儿」。
const double kTimelineBandHeight = 64;
const double kTimelineBandPadding = 16;
const double kTimelineBandDot = 8;
