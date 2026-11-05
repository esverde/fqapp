import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fqapp/pages/reader_page.dart';
import 'package:fqapp/pages/shuqi_detail_page.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('a toc failure keeps the book detail and offers a retry', (
    tester,
  ) async {
    var tocCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShuqiDetailPage(
          bookId: '34078',
          bookLoader: (_) async => {
            'data': {
              'bookId': '34078',
              'name': '凡人修仙传',
              'author': '忘语',
              'intro': '一个普通山村小子',
              'kind': '玄幻',
              'coverUrl': '',
              'wordCount': '2451万字',
              'lastChapter': '第2451章',
              'status': '完结',
              'chapterTotalNum': 2451,
            },
          },
          tocLoader: (_) async {
            tocCalls++;
            if (tocCalls == 1) throw StateError('toc down');
            return {
              'data': {
                'path': 'h5',
                'total': 1,
                'chapters': [
                  {'chapterId': '2180322', 'title': '第1章 山边小村', 'isVip': false},
                ],
              },
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 详情已经拿到，不能因为目录失败而整页报错。
    expect(find.text('忘语'), findsOneWidget);
    expect(find.text('一个普通山村小子'), findsOneWidget);
    expect(find.text('加载失败，请稍后重试'), findsOneWidget);
    // 「开始阅读」在目录为空时禁用，但详情本身仍然可见。
    expect(find.text('目录未加载'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '重试'));
    await tester.pumpAndSettle();

    expect(tocCalls, 2);
    expect(find.text('加载失败，请稍后重试'), findsNothing);
    expect(find.text('第1章 山边小村'), findsOneWidget);
    expect(find.text('共 1 章'), findsOneWidget);
  });

  testWidgets('resumes from saved history and reads cached chapters', (
    tester,
  ) async {
    // 墨卓：书旗也写进度、用章节缓存（键 shuqi:<id>）
    final store = MemoryReaderStore(entry: {
      'id': 'shuqi:34078',
      'kind': 'book',
      'chapterId': '2180323',
    });
    final cache = MemoryChapterCache();
    await cache.write(
      bookId: 'shuqi:34078',
      chapterId: '2180323',
      title: '第2章 青牛镇',
      text: '缓存里的正文',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShuqiDetailPage(
          bookId: '34078',
          readerStore: store,
          chapterCache: cache,
          bookLoader: (_) async => {
            'data': {
              'bookId': '34078',
              'name': '凡人修仙传',
              'author': '忘语',
              'coverUrl': '',
            },
          },
          tocLoader: (_) async => {
            'data': {
              'path': 'h5',
              'total': 2,
              'chapters': [
                {'chapterId': '2180322', 'title': '第1章 山边小村', 'isVip': false},
                {'chapterId': '2180323', 'title': '第2章 青牛镇', 'isVip': false},
              ],
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('继续阅读'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final reader = tester.widget<ReaderPage>(find.byType(ReaderPage));
    expect(reader.localOnly, isTrue);
    expect(reader.bookId, 'shuqi:34078');
    expect(reader.startIndex, 1);
    expect(identical(reader.readerStore, store), isTrue);
    expect(
      await reader.chapterLoader!(reader.chapters[1]),
      '缓存里的正文',
      reason: 'a cached chapter must not hit the network',
    );

    // 撤掉阅读器，别让还在跑的正文请求把 setState 带出测试。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
