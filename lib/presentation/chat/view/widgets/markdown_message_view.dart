import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:aigui/app/theme/app_theme.dart';

/// Renders rich Markdown messages with syntax-highlighted code blocks and clipboard copying.
class MarkdownMessageView extends StatelessWidget {
  const MarkdownMessageView({
    super.key,
    required this.content,
    this.isStreaming = false,
  });

  final String content;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.55,
          letterSpacing: 0.1,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          backgroundColor: isDark
              ? const Color(0xFF222736)
              : const Color(0xFFE8ECF5),
          color: isDark ? const Color(0xFF86E1FC) : const Color(0xFF006699),
        ),
        codeblockDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      builders: {
        'code': _CodeBlockBuilder(isDark: isDark),
      },
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder({required this.isDark});

  final bool isDark;

  @override
  Widget? visitElementAfter(mdElement, TextStyle? preferredStyle) {
    final text = mdElement.textContent;
    // Check if this is a fenced multiline codeblock
    final isMultiline = text.contains('\n');
    if (!isMultiline) return null;

    final infoString = mdElement.attributes['class'] ?? '';
    final language = infoString.startsWith('language-')
        ? infoString.substring('language-'.length)
        : 'plaintext';

    return _CodeBlockWidget(
      code: text,
      language: language.isNotEmpty ? language : 'code',
      isDark: isDark,
    );
  }
}

class _CodeBlockWidget extends StatelessWidget {
  const _CodeBlockWidget({
    required this.code,
    required this.language,
    required this.isDark,
  });

  final String code;
  final String language;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF08090E) : const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3145) : const Color(0xFF384059),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Code Block Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: isDark ? const Color(0xFF12151E) : const Color(0xFF282D3D),
            child: Row(
              children: [
                Text(
                  language.toLowerCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C95A8),
                  ),
                ),
                const Spacer(),
                _CopyCodeButton(code: code),
              ],
            ),
          ),

          // Syntax Highlighted Code
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code.trimRight(),
              language: language,
              theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyCodeButton extends StatefulWidget {
  const _CopyCodeButton({required this.code});

  final String code;

  @override
  State<_CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<_CopyCodeButton> {
  final ValueNotifier<bool> _copiedNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _copiedNotifier.dispose();
    super.dispose();
  }

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    _copiedNotifier.value = true;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _copiedNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _copiedNotifier,
      builder: (context, copied, _) {
        return InkWell(
          onTap: _copy,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 13,
                  color: copied ? AppTheme.nvidiaGreen : const Color(0xFF8C95A8),
                ),
                const SizedBox(width: 4),
                Text(
                  copied ? 'Copied' : 'Copy',
                  style: TextStyle(
                    fontSize: 11,
                    color: copied ? AppTheme.nvidiaGreen : const Color(0xFF8C95A8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
