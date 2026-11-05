import 'dart:async';

import 'package:flutter/material.dart';

import '../models/shuqi_book.dart';
import '../services/api_client.dart';
import '../services/chapter_cache_store.dart';
import '../services/library_store.dart';
import '../services/reader_history.dart';
import '../services/user_facing_error.dart';
import 'reader_page.dart';

/// 书旗书籍详情 + 目录。
///
/// 阅读器以 `localOnly: true` 打开，跳过番茄那套目录同步、段评和章节刷新。
/// 墨卓：进度 / 历史写进本机书架存储（[readerStore]），读过的章节写进章节缓存
/// （[chapterCache]，取章时先查缓存，断网也能读已读过的章节），键都是 `shuqi:<id>`。
///
/// 书旗 bookId 与番茄同为纯数字，所以在阅读器里加 `shuqi:` 前缀，避免两套 id
/// 在同一条进度/缓存键上相撞。
class ShuqiDetailPage extends StatefulWidget {
  final String bookId;

  /// 搜索结果带过来的标题/封面，只用于首屏占位，加载完成后以详情为准。
  final String initialTitle;
  final String initialCover;

  /// 注入点：留空走后端，与 SearchPage 的 loader 约定一致。
  final Future<Map<String, dynamic>> Function(String bookId)? bookLoader;
  final Future<Map<String, dynamic>> Function(String bookId)? tocLoader;

  /// 注入点：留空用本机书架存储、章节缓存。
  final ReaderStore? readerStore;
  final ChapterCache? chapterCache;

  const ShuqiDetailPage({
    super.key,
    required this.bookId,
    this.initialTitle = '',
    this.initialCover = '',
    this.bookLoader,
    this.tocLoader,
    this.readerStore,
    this.chapterCache,
  });

  @override
  State<ShuqiDetailPage> createState() => _ShuqiDetailPageState();
}

class _ShuqiDetailPageState extends State<ShuqiDetailPage> {
  ShuqiBook? _book;
  ShuqiToc? _toc;
  bool _loading = true;
  String? _error;

  /// 目录的加载/错误状态独立于详情：目录失败时详情照常展示。
  bool _tocLoading = true;
  String? _tocError;

  /// 上次读到的章节（历史里的 chapterId），有就「继续阅读」
  String? _resumeChapterId;

  String get _readerId => 'shuqi:${widget.bookId}';
  ReaderStore get _store => widget.readerStore ?? LibraryStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadResume());
  }

  Future<void> _loadResume() async {
    try {
      final saved = await ReaderHistory(_store).load(_readerId);
      final id = saved?['chapterId']?.toString();
      if (mounted && id != null && id.isNotEmpty) {
        setState(() => _resumeChapterId = id);
      }
    } catch (_) {
      // 读不到历史就从第一章开始
    }
  }

  int get _resumeIndex {
    final i = _toc?.chapters.indexWhere((c) => c.chapterId == _resumeChapterId) ?? -1;
    return i < 0 ? 0 : i;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tocLoading = true;
      _tocError = null;
    });
    // 详情与目录互不依赖，并行发出：目录首次可能是一次整本 H5 页。
    await Future.wait([_loadBook(), _loadToc()]);
  }

  Future<void> _loadBook() async {
    try {
      final loader = widget.bookLoader ?? ApiClient.instance.shuqiBook;
      final payload = await loader(widget.bookId);
      if (!mounted) return;
      final detail = payload['data'];
      setState(() {
        _book = detail is Map
            ? ShuqiBook.fromJson(Map<String, dynamic>.from(detail))
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadToc() async {
    setState(() {
      _tocLoading = true;
      _tocError = null;
    });
    try {
      final loader = widget.tocLoader ?? ApiClient.instance.shuqiToc;
      final payload = await loader(widget.bookId);
      if (!mounted) return;
      final toc = payload['data'];
      setState(() {
        _toc = ShuqiToc.fromJson(
          toc is Map ? Map<String, dynamic>.from(toc) : null,
        );
        _tocLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tocError = userFacingError(error);
        _tocLoading = false;
      });
    }
  }

  Future<void> _openChapter(int index) async {
    final book = _book;
    final toc = _toc;
    if (book == null || toc == null || toc.chapters.isEmpty) return;
    final start = index < 0 ? 0 : (index >= toc.chapters.length ? 0 : index);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          bookId: _readerId,
          title: book.name,
          cover: book.coverUrl,
          chapters: toc.toReaderChapters(),
          startIndex: start,
          localOnly: true,
          readerStore: _store,
          chapterLoader: (chapter) async {
            final cache = widget.chapterCache ?? ChapterCacheStore.instance;
            try {
              final hit = await cache.read(bookId: _readerId, chapterId: chapter.itemId);
              if (hit != null && hit.trim().isNotEmpty) return hit;
            } catch (_) {
              // 缓存坏了照常联网取
            }
            final payload = await ApiClient.instance.shuqiChapter(
              widget.bookId,
              chapter.itemId,
            );
            final data = payload['data'];
            final text = data is Map ? data['content'] : null;
            if (text is! String || text.isEmpty) {
              throw StateError('这一章没有取到正文（${chapter.title}）');
            }
            unawaited(cache
                .write(bookId: _readerId, chapterId: chapter.itemId, title: chapter.title, text: text)
                .catchError((_) {})); // 写不进缓存不影响阅读
            return text;
          },
        ),
      ),
    );    if (mounted) unawaited(_loadResume()); // 回来时按钮跟上刚读到的章节
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _book?.name.isNotEmpty == true
        ? _book!.name
        : (widget.initialTitle.isEmpty ? '书旗' : widget.initialTitle);
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    final book = _book;
    if (book == null) {
      return const Center(child: Text('没有取到书籍数据'));
    }
    // 目录失败或还没回来时，详情照常展示，目录区单独给出状态与重试。
    final toc = _toc;
    if (toc == null) {
      return ListView(
        children: [_buildHeader(theme, book, null), _buildTocStatus()],
      );
    }
    return ListView.builder(
      itemCount: toc.chapters.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(theme, book, toc);
        final chapter = toc.chapters[index - 1];
        return ListTile(
          dense: true,
          title: Text(
            chapter.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: chapter.isVip
              ? Text('VIP', style: theme.textTheme.labelSmall)
              : null,
          onTap: () => _openChapter(index - 1),
        );
      },
    );
  }

  Widget _buildTocStatus() {
    if (_tocLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          Text(_tocError ?? '没有取到目录', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadToc, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ShuqiBook book, ShuqiToc? toc) {
    final chapters = toc?.chapters ?? const <ShuqiChapter>[];
    final meta = [
      book.status,
      book.wordCount,
      book.kind,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(theme, book),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(book.author, style: theme.textTheme.bodySmall),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: chapters.isEmpty
                          ? null
                          : () => _openChapter(_resumeIndex),
                      child: Text(_resumeChapterId == null ? '开始阅读' : '继续阅读'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (book.intro.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              book.intro,
              style: theme.textTheme.bodySmall,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                toc == null ? '目录未加载' : '共 ${chapters.length} 章',
                style: theme.textTheme.titleSmall,
              ),
              if (toc != null && !toc.hasRealTitles) ...[
                const SizedBox(width: 8),
                Text('（章名为占位）', style: theme.textTheme.bodySmall),
              ],
              const Spacer(),
              Text('书旗', style: theme.textTheme.bodySmall),
            ],
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildCover(ThemeData theme, ShuqiBook book) {
    const width = 68.0;
    const height = 94.0;
    final fallback = Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book_outlined, size: 28),
    );
    if (book.coverUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        book.coverUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
