import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../../core/design_system.dart';

/// Schermata dedicata per i documenti legali (Privacy, EULA, Termini):
/// titolo, sezioni con veri Divider e link tappabili.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.shield_rounded,
  });

  TextSpan _linkifyText(String text, TextStyle style, Color linkColor) {
    final urlRegExp = RegExp(r'https?://[^\s)]+');
    final spans = <TextSpan>[];
    int start = 0;
    for (final match in urlRegExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri == null) return;
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(style: style, children: spans);
  }

  List<Widget> _buildSections(ThemeProvider theme) {
    final bodyStyle = TextStyle(
      color: theme.textColor,
      fontSize: 13.5,
      height: 1.65,
    );
    final parts = content.split(RegExp(r'\n[━─=\-]{5,}\n'));
    if (parts.length < 3) {
      return [
        RichText(
          textAlign: TextAlign.center,
          text: _linkifyText(content, bodyStyle, theme.primaryColor),
        ),
      ];
    }
    final widgets = <Widget>[
      Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: _linkifyText(
            parts[0].trim(),
            TextStyle(
              color: theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            theme.primaryColor,
          ),
        ),
      ),
      const SizedBox(height: 8),
    ];
    for (int i = 1; i < parts.length; i += 2) {
      final header = parts[i].trim();
      final body = (i + 1 < parts.length) ? parts[i + 1].trim() : '';
      widgets.addAll([
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppGradients.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                header,
                style: TextStyle(
                  fontFamily: 'Syne',
                  color: theme.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        Divider(
          color: theme.primaryColor.withOpacity(0.3),
          thickness: 1.2,
          height: 18,
        ),
        if (body.isNotEmpty)
          RichText(
            text: _linkifyText(body, bodyStyle, theme.primaryColor),
          ),
      ]);
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppGradients.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape =
                orientation == Orientation.landscape;
            final horizontalPad = isLandscape
                ? 32.0 + MediaQuery.of(context).padding.left
                : 20.0;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLandscape ? 700 : 600,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    16,
                    isLandscape ? 32.0 + MediaQuery.of(context).padding.right : 20,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSections(theme),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
