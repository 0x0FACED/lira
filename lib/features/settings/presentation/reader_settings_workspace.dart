import 'dart:async';
import 'dart:math' as math;

import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/settings_provider.dart';
import 'reader_page_dimming.dart';
import 'settings_panel.dart';

/// Keeps the live reader mounted while settings or the sample are visible.
class ReaderSettingsWorkspace extends StatefulWidget {
  const ReaderSettingsWorkspace({
    super.key,
    required this.isOpen,
    required this.onOpen,
    required this.onClose,
    required this.child,
    this.previewOnly = false,
  });

  final bool isOpen;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final Widget child;
  final bool previewOnly;

  @override
  State<ReaderSettingsWorkspace> createState() =>
      _ReaderSettingsWorkspaceState();
}

class _ReaderSettingsWorkspaceState extends State<ReaderSettingsWorkspace> {
  bool _sampleSelected = false;
  bool _sampleOpened = false;
  bool _panelVisible = false;
  final _bookStorage = PageStorageBucket();
  final _sampleStorage = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isOpen) {
        setState(() => _panelVisible = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ReaderSettingsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      _panelVisible = widget.isOpen;
    }
  }

  void _backToBook() {
    if (widget.isOpen) {
      widget.onClose();
    } else if (_sampleSelected && !widget.previewOnly) {
      setState(() => _sampleSelected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final sampleVisible = widget.previewOnly || _sampleSelected;
    if (sampleVisible) _sampleOpened = true;

    return CallbackShortcuts(
      bindings: {
        if (widget.isOpen || (_sampleSelected && !widget.previewOnly))
          const SingleActivator(LogicalKeyboardKey.escape): _backToBook,
      },
      child: PopScope(
        canPop: !widget.isOpen && (widget.previewOnly || !_sampleSelected),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _backToBook();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide =
                constraints.maxWidth >= 760 && constraints.maxHeight >= 500;
            final panelWidth = (constraints.maxWidth * 0.38).clamp(
              320.0,
              400.0,
            );
            final panelHeight = math.max(
              0.0,
              math.min(
                constraints.maxHeight * 0.52,
                constraints.maxHeight - 160,
              ),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  // Reflow once per open/close, never on each animation frame.
                  left: widget.isOpen && sideBySide ? panelWidth : 0,
                  right: 0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Offstage(
                        offstage: sampleVisible,
                        child: TickerMode(
                          enabled: !sampleVisible,
                          child: PageStorage(
                            bucket: _bookStorage,
                            child: widget.child,
                          ),
                        ),
                      ),
                      if (_sampleOpened)
                        Offstage(
                          offstage: !sampleVisible,
                          child: TickerMode(
                            enabled: sampleVisible,
                            child: PageStorage(
                              bucket: _sampleStorage,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: !widget.previewOnly && !widget.isOpen
                                      ? AppLayout.minTouchTarget +
                                            AppSpacing.sm * 2
                                      : 0,
                                ),
                                child: const _ReaderSample(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (sampleVisible && !widget.isOpen && !widget.previewOnly)
                  Positioned(
                    key: const ValueKey('reader-preview-actions'),
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      minimum: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            tooltip: l10n.readerCurrentBook,
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _backToBook,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filledTonal(
                            tooltip: l10n.readerSettings,
                            icon: const Icon(Icons.settings),
                            onPressed: widget.onOpen,
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  key: const ValueKey('reader-settings-position'),
                  top: sideBySide ? 0 : null,
                  bottom: 0,
                  left: 0,
                  right: sideBySide ? null : 0,
                  width: sideBySide ? panelWidth : null,
                  height: sideBySide ? null : panelHeight,
                  child: IgnorePointer(
                    ignoring: !widget.isOpen,
                    child: ExcludeFocus(
                      excluding: !widget.isOpen,
                      child: ExcludeSemantics(
                        excluding: !widget.isOpen,
                        child: AnimatedSlide(
                          duration: AppMotion.duration(
                            context,
                            widget.isOpen ? AppMotion.slow : AppMotion.normal,
                          ),
                          curve: widget.isOpen
                              ? AppMotion.curve
                              : Curves.easeInCubic,
                          offset: _panelVisible
                              ? Offset.zero
                              : sideBySide
                              ? const Offset(-1, 0)
                              : const Offset(0, 1),
                          child: Material(
                            key: const ValueKey('reader-settings-surface'),
                            color: colors.surface,
                            elevation: sideBySide ? 0 : 12,
                            clipBehavior: Clip.antiAlias,
                            shape: sideBySide
                                ? Border(
                                    right: BorderSide(
                                      color: colors.outlineVariant,
                                    ),
                                  )
                                : const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(AppSpacing.md),
                                    ),
                                  ),
                            child: SafeArea(
                              right: !sideBySide,
                              top: sideBySide,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      4,
                                      0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.previewOnly
                                                ? l10n.readerPreviewTitle
                                                : l10n.readerSettings,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: l10n.readerCloseSettings,
                                          icon: const Icon(Icons.close),
                                          onPressed: widget.onClose,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!widget.previewOnly)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: SegmentedButton<bool>(
                                        showSelectedIcon: false,
                                        segments: [
                                          ButtonSegment(
                                            value: false,
                                            label: Text(l10n.readerCurrentBook),
                                          ),
                                          ButtonSegment(
                                            value: true,
                                            label: Text(l10n.readerPreviewBook),
                                          ),
                                        ],
                                        selected: {_sampleSelected},
                                        onSelectionChanged: (value) => setState(
                                          () => _sampleSelected = value.single,
                                        ),
                                      ),
                                    ),
                                  const Expanded(child: SettingsPanel()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ReaderCustomizationScreen extends ConsumerStatefulWidget {
  const ReaderCustomizationScreen({super.key});

  @override
  ConsumerState<ReaderCustomizationScreen> createState() =>
      _ReaderCustomizationScreenState();
}

class _ReaderCustomizationScreenState
    extends ConsumerState<ReaderCustomizationScreen> {
  bool _settingsOpen = true;

  void _closeSettings() {
    setState(() => _settingsOpen = false);
    unawaited(
      ref
          .read(readerSettingsProvider.notifier)
          .flush()
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(l10n.readerCustomize),
        actions: [
          if (!_settingsOpen)
            IconButton(
              tooltip: l10n.readerSettings,
              icon: const Icon(Icons.settings),
              onPressed: () => setState(() => _settingsOpen = true),
            ),
        ],
      ),
      body: ReaderSettingsWorkspace(
        isOpen: _settingsOpen,
        previewOnly: true,
        onOpen: () => setState(() => _settingsOpen = true),
        onClose: _closeSettings,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ReaderSample extends ConsumerStatefulWidget {
  const _ReaderSample();

  @override
  ConsumerState<_ReaderSample> createState() => _ReaderSampleState();
}

class _ReaderSampleState extends ConsumerState<_ReaderSample> {
  late final Future<ParsedEpub> _book = _load();

  Future<ParsedEpub> _load() async {
    final bytes = await rootBundle.load('assets/reader/reading_sample.epub');
    return EpubParser.parse(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Color(settings.backgroundColor),
      child: FutureBuilder<ParsedEpub>(
        future: _book,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.readerPreviewError));
          }
          final book = snapshot.data;
          if (book == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            child: ReaderPageDimming(
              brightness: settings.brightness,
              child: EpubNativeView(
                epub: book,
                settings: settings,
                theme: Theme.of(context),
                initialLocation: EpubLocation.fromPosition(
                  chapterIndex: l10n.localeName.startsWith('ru') ? 0 : 1,
                  hasExactCharOffset: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
