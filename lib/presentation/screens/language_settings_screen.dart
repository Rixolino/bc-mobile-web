import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../../core/services/runtime_localizations.dart';

/// Schermata dedicata alla scelta della lingua (aperta dalle impostazioni).
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
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
        title: Text(
          RuntimeLocalizations.t(context, 'settings_language',
              fallback: 'Lingua'),
          style: TextStyle(
              color: theme.textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _languageOption(
            context,
            settings,
            theme,
            label: RuntimeLocalizations.t(context, 'automatic',
                fallback: 'Automatica'),
            langCode: null,
            leading: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: settings.isLocaleAutomatic
                  ? theme.primaryColor
                  : theme.secondaryTextColor,
            ),
          ),
          _languageOption(
            context,
            settings,
            theme,
            label: RuntimeLocalizations.t(context, 'language_italian',
                fallback: 'Italiano'),
            langCode: 'it',
            leading: const Text('🇮🇹', style: TextStyle(fontSize: 18)),
          ),
          _languageOption(
            context,
            settings,
            theme,
            label: RuntimeLocalizations.t(context, 'language_english',
                fallback: 'English'),
            langCode: 'en',
            leading: const Text('🇬🇧', style: TextStyle(fontSize: 18)),
          ),
          _languageOption(
            context,
            settings,
            theme,
            label: RuntimeLocalizations.t(context, 'language_german',
                fallback: 'Deutsch'),
            langCode: 'de',
            leading: const Text('🇩🇪', style: TextStyle(fontSize: 18)),
          ),
          _languageOption(
            context,
            settings,
            theme,
            label: RuntimeLocalizations.t(context, 'language_french',
                fallback: 'Français'),
            langCode: 'fr',
            leading: const Text('🇫🇷', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _languageOption(
    BuildContext context,
    SettingsProvider settings,
    ThemeProvider theme, {
    required String label,
    required String? langCode,
    required Widget leading,
  }) {
    final isSelected = langCode == null
        ? settings.isLocaleAutomatic
        : settings.appLocale?.languageCode == langCode;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? theme.primaryColor.withOpacity(0.08)
          : theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.4)
              : theme.secondaryTextColor.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.15)
                : theme.surfaceColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: leading,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.primaryColor : theme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: theme.primaryColor)
            : null,
        onTap: () => settings.setAppLocale(langCode),
      ),
    );
  }
}
