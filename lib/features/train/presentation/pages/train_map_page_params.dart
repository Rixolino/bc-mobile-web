import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

// ----------------------------------------------------------------------------------
// ISOLATE FUNCTION: Parses Overpass JSON and returns unordered segments (BULK)
// ----------------------------------------------------------------------------------
Future<List<List<LatLng>>?> parseRailwaySegmentsOnly(String body) async {
  try {
    final data = json.decode(body);
    final elements = data['elements'] as List?;
      
    if (elements == null) return null;
    
    List<List<LatLng>> allSegments = [];
    
    for (var element in elements) {
      if (element['type'] != 'way') continue;
      final geometry = element['geometry'] as List?;
      if (geometry == null || geometry.isEmpty) continue;
      
      final wayPoints = geometry.map((point) {
        return LatLng(
          (point['lat'] as num).toDouble(),
          (point['lon'] as num).toDouble()
        );
      }).toList();

      if (wayPoints.isNotEmpty) {
          allSegments.add(wayPoints);
      }
    }
    return allSegments;
  } catch (e) {
    debugPrint("Isolate parsing error (bulk): $e");
    return null;
  }
}

// ----------------------------------------------------------------------------------
// ISOLATE FUNCTION: Parses Overpass JSON and orders tracks without blocking UI
// ----------------------------------------------------------------------------------
Future<List<List<LatLng>>?> parseAndOrderRailway(Map<String, dynamic> params) async {
  try {
    final String body = params['body'];
    final double startLat = params['startLat'];
    final double startLng = params['startLng'];
    final double endLat = params['endLat'];
    final double endLng = params['endLng'];

    final LatLng start = LatLng(startLat, startLng);
    // Not strictly needed for logic but good for target
    // final LatLng end = LatLng(endLat, endLng); 

    final data = json.decode(body);
    final elements = data['elements'] as List?;
      
    if (elements == null || elements.isEmpty) {
      return null;
    }
    
    // 1. Extract Segments
    List<List<LatLng>> allSegments = [];
    
    for (var element in elements) {
      if (element['type'] != 'way') continue;
      final geometry = element['geometry'] as List?;
      if (geometry == null || geometry.isEmpty) continue;
      
      final wayPoints = geometry.map((point) {
        return LatLng(
          (point['lat'] as num).toDouble(),
          (point['lon'] as num).toDouble()
        );
      }).toList();

      if (wayPoints.isNotEmpty) {
          allSegments.add(wayPoints);
      }
    }
     
    // 2. Order Segments (Greedy Algorithm)
    // Instantiating Distance here because it's an Isolate
    const Distance distCalc = Distance();
    
    if (allSegments.isEmpty) return [];
      
    final List<List<LatLng>> ordered = [];
    final List<List<LatLng>> available = List.from(allSegments);
    LatLng currentPos = start;
    const double maxJumpDist = 5000; // 5km

    while (available.isNotEmpty) {
        int bestIdx = -1;
        double bestDist = double.infinity;
        bool reverseBest = false;
        
        for (int i = 0; i < available.length; i++) {
            final seg = available[i];
            if (seg.isEmpty) continue;
            
            final d1 = distCalc.as(LengthUnit.Meter, currentPos, seg.first);
            if (d1 < bestDist) {
                bestDist = d1;
                bestIdx = i;
                reverseBest = false;
            }
            
            final d2 = distCalc.as(LengthUnit.Meter, currentPos, seg.last);
            if (d2 < bestDist) {
                bestDist = d2;
                bestIdx = i;
                reverseBest = true;
            }
        }
        
        if (bestIdx != -1) {
            // Optional: check maxJumpDist vs bestDist
            
            final seg = available.removeAt(bestIdx);
            if (reverseBest) {
                ordered.add(seg.reversed.toList());
                currentPos = seg.first; 
            } else {
                ordered.add(seg);
                currentPos = seg.last; 
            }
        } else {
            break; 
        }
    }
    
    return ordered;

  } catch (e) {
    debugPrint("Isolate parsing error: $e");
    return null;
  }
}
