import re

file_path = 'lib/features/train/presentation/widgets/train_stats_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix params syntax
content = content.replace(
    "RuntimeLocalizations.t(context, 'train_stats_avg_delay', {'delay': stop.averageDelay.toString()})",
    "RuntimeLocalizations.t(context, 'train_stats_avg_delay', params: {'delay': stop.averageDelay.toString()})"
)
content = content.replace(
    "RuntimeLocalizations.t(context, 'train_stats_cancellations', {'rate': stop.cancellationRate.toString(), 'logs': stop.totalLogs.toString()})",
    "RuntimeLocalizations.t(context, 'train_stats_cancellations', params: {'rate': stop.cancellationRate.toString(), 'logs': stop.totalLogs.toString()})"
)

# Fix dead null aware expressions
content = content.replace(
    "backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest ?? Colors.grey[200],",
    "backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,"
)
content = content.replace(
    "color: Theme.of(context).colorScheme.surfaceContainerHighest ?? Colors.grey[50],",
    "color: Theme.of(context).colorScheme.surfaceContainerHighest,"
)

# Fix withOpacity
content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed dart errors")
