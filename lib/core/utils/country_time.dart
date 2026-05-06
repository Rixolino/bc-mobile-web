import 'package:intl/intl.dart';

const Map<String, int> _standardUtcOffsets = {
  'GB': 0,
  'IE': 0,
  'PT': 0,
  'IS': 0,
  'IT': 1,
  'FR': 1,
  'DE': 1,
  'AT': 1,
  'CH': 1,
  'ES': 1,
  'NL': 1,
  'BE': 1,
  'LU': 1,
  'CZ': 1,
  'PL': 1,
  'HU': 1,
  'SE': 1,
  'NO': 1,
  'DK': 1,
  'SI': 1,
  'HR': 1,
  'SK': 1,
  'RO': 2,
  'GR': 2,
  'FI': 2,
  'EE': 2,
  'LV': 2,
  'LT': 2,
  'BG': 2,
};

const Set<String> _europeanDstCountries = {
  'GB',
  'IE',
  'PT',
  'IT',
  'FR',
  'DE',
  'AT',
  'CH',
  'ES',
  'NL',
  'BE',
  'LU',
  'CZ',
  'PL',
  'HU',
  'SE',
  'NO',
  'DK',
  'SI',
  'HR',
  'SK',
  'RO',
  'GR',
  'FI',
  'EE',
  'LV',
  'LT',
  'BG',
};

String formatCountryTime(DateTime? date, String? countryCode) {
  if (date == null) return '--:--';
  return DateFormat('HH:mm').format(toCountryLocalTime(date, countryCode));
}

DateTime toCountryLocalTime(DateTime date, String? countryCode) {
  final utc = date.toUtc();
  final country = (countryCode ?? '').toUpperCase();
  final standardOffset = _standardUtcOffsets[country];

  if (standardOffset == null) {
    return utc.toLocal();
  }

  final dstOffset = _usesEuropeanDst(country) && _isEuropeanDst(utc) ? 1 : 0;
  return utc.add(Duration(hours: standardOffset + dstOffset));
}

bool _usesEuropeanDst(String countryCode) {
  return _europeanDstCountries.contains(countryCode);
}

bool _isEuropeanDst(DateTime utc) {
  final start = _lastSundayUtc(utc.year, DateTime.march, hour: 1);
  final end = _lastSundayUtc(utc.year, DateTime.october, hour: 1);
  return !utc.isBefore(start) && utc.isBefore(end);
}

DateTime _lastSundayUtc(int year, int month, {required int hour}) {
  final lastDay = DateTime.utc(year, month + 1, 0, hour);
  final daysBack = lastDay.weekday % DateTime.daysPerWeek;
  return lastDay.subtract(Duration(days: daysBack));
}
