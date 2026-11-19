import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../pages/about_page.dart';
import '../../pages/cached_books_page.dart';
import '../../pages/cached_dramas_page.dart';
import '../../pages/library_backup_page.dart';
import '../../pages/settings_page.dart';
import '../../services/app_style_tokens.dart';
import '../home/home_sheet.dart';
import '../wenku/wenku_ui.dart';

/// “我的”页的入口卡片，顺序沿用 Wenku8 Flutter 的设置／数据分层。
class MineEntries extends StatelessWidget {
  const MineEntries({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppStyleTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeatureEntry(
          key: const ValueKey('mine-settings'),
          title: '设置',
          subtitle: '阅读、外观、播放与本地数据',
          icon: CupertinoIcons.settings,
          onTap: () => _push(context, const SettingsPage()),
        ),
        SizedBox(height: style.entryGap),
        FeatureEntry(
          key: const ValueKey('mine-cache'),
          title: '离线缓存',
          subtitle: '管理小说的离线内容',
          icon: CupertinoIcons.tray_arrow_down,
          onTap: () => _push(context, const CachedBooksPage()), // 墨卓精简版只有小说缓存
        ),
        SizedBox(height: style.entryGap),
        FeatureEntry(
          key: const ValueKey('mine-backup'),
          title: '备份与导入',
          subtitle: '本机备份、恢复与外部书架导入',
          icon: CupertinoIcons.archivebox,
          onTap: () => _push(context, const LibraryBackupPage()),
        ),
        SizedBox(height: style.entryGap),
        // 上游“关于”副标题显示版本与更新状态；fqapp 没有 AppUpdates 模块，
        // 这里用静态说明替代。
        FeatureEntry(
          key: const ValueKey('mine-about'),
          title: '关于',
          subtitle: '版本与应用信息',
          icon: CupertinoIcons.info_circle,
          onTap: () => _push(context, const AboutPage()),
        ),
      ],
    );
  }
}

void _push(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

