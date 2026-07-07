import os

loc_file = 'lib/core/services/runtime_localizations.dart'
screen_file = 'lib/features/train/presentation/widgets/train_stats_screen.dart'

# Update runtime_localizations.dart
with open(loc_file, 'r', encoding='utf-8') as f:
    loc_content = f.read()

# Add Italian
it_hook = "      // -- Train Stats Screen --"
it_add = """      'train_stats_stops_analysis': 'Analisi Fermate (Storico)',
      'train_stats_avg_delay': '{delay} min ritardo medio',
      'train_stats_cancellations': '{rate}% cancellazioni ({logs} rilevamenti)',"""
if 'train_stats_stops_analysis' not in loc_content:
    # We will just inject it in the dicts
    loc_content = loc_content.replace(
        "      // -- Train Stats Screen --\n",
        "      // -- Train Stats Screen --\n" + it_add + "\n"
    )

    # English
    en_add = """      'train_stats_stops_analysis': 'Stops Analysis (Historical)',
      'train_stats_avg_delay': '{delay} min average delay',
      'train_stats_cancellations': '{rate}% cancellations ({logs} logs)',"""
    loc_content = loc_content.replace(
        "    'en': {\n      // -- Train Stats Screen --",
        "    'en': {\n      // -- Train Stats Screen --\n" + en_add
    )
    
    # German
    de_add = """      'train_stats_stops_analysis': 'Haltestellenanalyse (Historisch)',
      'train_stats_avg_delay': '{delay} Min. Durchschnittliche Verspätung',
      'train_stats_cancellations': '{rate}% Ausfälle ({logs} Erfassungen)',"""
    loc_content = loc_content.replace(
        "    'de': {\n      // -- Train Stats Screen --",
        "    'de': {\n      // -- Train Stats Screen --\n" + de_add
    )

with open(loc_file, 'w', encoding='utf-8') as f:
    f.write(loc_content)


# Update train_stats_screen.dart
with open(screen_file, 'r', encoding='utf-8') as f:
    screen_content = f.read()

screen_content = screen_content.replace(
    'Text(\n          "Analisi Fermate (Storico)",',
    'Text(\n          RuntimeLocalizations.t(context, \'train_stats_stops_analysis\'),'
)

screen_content = screen_content.replace(
    'Text(\n                      "${stop.averageDelay} min ritardo medio",',
    'Text(\n                      RuntimeLocalizations.t(context, \'train_stats_avg_delay\', {\'delay\': stop.averageDelay.toString()}),'
)

screen_content = screen_content.replace(
    'Text(\n                      "${stop.cancellationRate}% cancellazioni (${stop.totalLogs} rilevamenti)",',
    'Text(\n                      RuntimeLocalizations.t(context, \'train_stats_cancellations\', {\'rate\': stop.cancellationRate.toString(), \'logs\': stop.totalLogs.toString()}),'
)

with open(screen_file, 'w', encoding='utf-8') as f:
    f.write(screen_content)

print("Translations updated successfully.")
