import 'package:flutter/material.dart';

import '../../../services/reader_preferences.dart';
import '../reader_scroll_mode_setting.dart';
import 'reader_settings_widgets.dart';

/// 翻页与滚动跨章共用上游设置行；分页时不显示跨章选项。
class ReaderTurnSettings extends StatelessWidget {
  const ReaderTurnSettings({
    super.key,
    required this.value,
    required this.onChanged,
    this.eink = false,
  });

  final ReaderPreferences value;

  /// 全局墨水屏：翻页动画被强制关掉（einkEffectiveTurnStyle），分页时总是显示「无」
  final bool eink;
  final ValueChanged<ReaderPreferences> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _turnRow(),
      if (value.pageMode == ReaderPageMode.scroll)
        ReaderScrollModeSetting(
          value: value.scrollChapterMode,
          onChanged: (mode) =>
              onChanged(value.copyWith(scrollChapterMode: mode)),
        ),
    ],
  );

  Widget _turnRow() {
    final pagedMode = value.pageMode == ReaderPageMode.paged;
    final none = pagedMode &&
        (eink ||
            value.instantSwipeTurn ||
            value.pageTurnStyle == ReaderPageTurnStyle.none);
    bool style(ReaderPageTurnStyle style) =>
        pagedMode && !none && value.pageTurnStyle == style;
    return ReaderSettingsRow(
      label: '翻页',
      child: ReaderSettingsChipRow(
        children: [
          // 墨卓：无动画翻页放回首屏（同「更多设置」的无动画翻页开关）
          ReaderSettingsChip(
            key: const ValueKey('reader-turn-none'),
            label: '无',
            selected: none,
            onTap: () => onChanged(
              value.copyWith(
                pageMode: ReaderPageMode.paged,
                pageTurnStyle: ReaderPageTurnStyle.none,
                instantSwipeTurn: true,
              ),
            ),
          ),
          ReaderSettingsChip(
            key: const ValueKey('reader-turn-curl'),
            label: '仿真',
            selected: style(ReaderPageTurnStyle.curl),
            onTap: () => _selectPagedStyle(ReaderPageTurnStyle.curl),
          ),
          ReaderSettingsChip(
            key: const ValueKey('reader-mode-paged'),
            label: '覆盖',
            selected: style(ReaderPageTurnStyle.cover),
            onTap: () => _selectPagedStyle(ReaderPageTurnStyle.cover),
          ),
          ReaderSettingsChip(
            key: const ValueKey('reader-turn-slide'),
            label: '平移',
            selected: style(ReaderPageTurnStyle.slide),
            onTap: () => _selectPagedStyle(ReaderPageTurnStyle.slide),
          ),
          ReaderSettingsChip(
            key: const ValueKey('reader-mode-scroll'),
            label: '滚动',
            selected: value.pageMode == ReaderPageMode.scroll,
            onTap: () =>
                onChanged(value.copyWith(pageMode: ReaderPageMode.scroll)),
          ),
        ],
      ),
    );
  }

  /// 选具体翻页方式即回到分页模式，并关掉「无动画翻页」。
  void _selectPagedStyle(ReaderPageTurnStyle style) => onChanged(
    value.copyWith(
      pageMode: ReaderPageMode.paged,
      pageTurnStyle: style,
      instantSwipeTurn: false,
    ),
  );
}
