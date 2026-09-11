/// 项目仓库地址。关于页的外链、海报二维码都指向它。
const String kRepoUrl = 'https://github.com/Muanyan-mjq/Time';

/// ↓↓↓ 海报二维码指向的地址 ↓↓↓
/// 留空 = 海报上不画二维码，其余排版自动适配（不会留空洞）。
const String kPosterShareUrl = kRepoUrl;

const String kAppName = 'Time';

/// 中文副标题。App 以 Time 为主名，「时光」作为副标题保留。
const String kAppSubName = '时光';

const String kAppSlogan = '每一个平凡的日子，都值得纪念';

/// 与 pubspec.yaml 的 version 保持一致。
const String kAppVersion = '1.1.0';

/// 表单留空时的默认文案，2020 年就是这个，不要改。
const String kDefaultHeadText = '生如夏花之灿烂';
const String kDefaultRemark = '只要面对着阳光努力向上，日子就会变得单纯而美好。';

/// 照片封面在应用文档目录下的子目录。
const String kCoversDir = 'covers';

/// 设置文件，和封面图同放在应用文档目录下。
const String kSettingsFileName = 'settings.json';

/// 桌面图标长按快捷方式的通道名。和 `MainActivity.kt` 里的 `kChannel` 逐字一致，
/// 对不上只是快捷方式失灵、不报错，所以两边都留了名字在这儿。
const String kShortcutChannel = 'com.muanyan.daily/shortcuts';
