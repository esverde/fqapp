part of '../reader_page.dart';

extension _ReaderPageMenuPlayers on _ReaderPageState {
  // 墨卓精简版：阅读菜单不放听书、看剧入口
  Widget _buildReaderMenuPlayers(ReaderThemePreset preset) =>
      const SizedBox.shrink();

  bool get _readerAudioUnavailable {
    final tones = _readerTones;
    return !widget.localOnly &&
        tones != null &&
        !tones.hasFixedTone &&
        tones.ttsTones.isEmpty &&
        tones.narratorTones.isEmpty;
  }

  void _loadReaderMenuData() {} // 墨卓精简版：不查改编剧、不查听书音色

  Future<void> _loadReaderTones() async {
    if (widget.localOnly ||
        widget.chapters.isEmpty ||
        _readerTones != null ||
        _readerTonesRequest != null) {
      return;
    }
    final now = DateTime.now();
    if (_readerTonesAttempt != null &&
        now.difference(_readerTonesAttempt!) < const Duration(seconds: 15)) {
      return;
    }
    _readerTonesAttempt = now;
    final request = _readerTonesRequest = BackendRequest();
    try {
      final tones = await ApiClient.instance.withCancellation(
        request,
        () => ApiClient.instance.bookTones(widget.bookId),
      );
      if (mounted && !request.isCancelled) {
        _setState(() => _readerTones = tones);
      }
    } catch (_) {
      // Unknown availability is retryable, not a copyright denial.
    } finally {
      if (identical(_readerTonesRequest, request)) _readerTonesRequest = null;
    }
  }
}
