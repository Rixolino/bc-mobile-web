import 'package:flutter/material.dart';
import '../../data/models/roadway_service_model.dart';
import '../../utils/brand_logos.dart';
import '../../../../core/design_system.dart';

class RoadwayAreaServiceScreen extends StatelessWidget {
  final RoadwayAreaService area;
  final bool isGerman;

  const RoadwayAreaServiceScreen({
    super.key,
    required this.area,
    this.isGerman = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Solo layout: in landscape altezza ridotta e contenuti affiancati.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 0,
            pinned: true,
            expandedHeight: isLandscape ? 80 : 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                area.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content (solo layout: in landscape due colonne vincolate)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLandscape ? 1000 : double.infinity,
                ),
                child: Padding(
              padding: EdgeInsets.all(isLandscape ? 12 : 16),
              child: isLandscape
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildInfoCard(context, theme, isDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (area.fuelPrices.values
                                      .any((f) => f.price > 0))
                                    _buildFuelPricesSection(theme),
                                  if (area.events.isNotEmpty)
                                    _buildEventsSection(theme),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Services
                        if (area.services.isNotEmpty)
                          _buildServicesSection(context, theme, isDark),

                        // Brands (fuel + food logos)
                        if (area.fuelBrand.isNotEmpty ||
                            area.foodBrands.isNotEmpty)
                          _buildBrandsSection(theme),
                      ],
                    )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  _buildInfoCard(context, theme, isDark),
                  const SizedBox(height: 16),

                  // Fuel prices
                  if (area.fuelPrices.values.any((f) => f.price > 0))
                    _buildFuelPricesSection(theme),

                  // Events
                  if (area.events.isNotEmpty)
                    _buildEventsSection(theme),

                  // Services
                  if (area.services.isNotEmpty)
                    _buildServicesSection(context, theme, isDark),

                  // Brands (fuel + food logos)
                  if (area.fuelBrand.isNotEmpty || area.foodBrands.isNotEmpty)
                    _buildBrandsSection(theme),
                ],
              ),
            ),
                ),
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Icon(
                  Icons.local_gas_station_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (area.highway.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        ),
                        child: Text(
                          area.highway,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (area.km > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.straighten_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'Km ${area.km.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Direction
          if (area.direction.isNotEmpty && area.direction.toLowerCase() != 'undefined')
            _infoRow(
              theme,
              Icons.navigation_rounded,
              theme.colorScheme.primary,
              '${isGerman ? 'Richtung' : 'Direzione'}: ${area.direction}',
            ),

          // Route
          if (area.from.isNotEmpty || area.to.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _infoRow(
                theme,
                Icons.route_outlined,
                theme.colorScheme.onSurfaceVariant,
                '${isGerman ? 'Strecke' : 'Tratta'}: ${area.from} → ${area.to}',
              ),
            ),

          // PMR
          if (area.descriptionAdsPmr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _infoRow(
                theme,
                Icons.accessible_rounded,
                theme.colorScheme.primary,
                'PMR: ${area.descriptionAdsPmr}',
              ),
            ),

          // Parking
          if (area.parking != null &&
              (area.parking!.carSpaces != null || area.parking!.truckSpaces != null))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _infoRow(
                theme,
                Icons.local_parking_rounded,
                theme.colorScheme.onSurfaceVariant,
                [
                  if (area.parking!.carSpaces != null) '${isGerman ? 'PKW' : 'Auto'}: ${area.parking!.carSpaces}',
                  if (area.parking!.truckSpaces != null) '${isGerman ? 'LKW' : 'Camion'}: ${area.parking!.truckSpaces}',
                  if (area.parking!.isBlocked == true) (isGerman ? 'gesperrt' : 'bloccato'),
                ].join(' • '),
              ),
            ),

          // Fuel brand
          if (area.fuelBrand.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.local_gas_station_outlined, size: 16, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Text(
                    area.fuelBrand,
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFuelPricesSection(ThemeData theme) {
    final priceEntries = area.fuelPrices.entries.where((e) => e.value.price > 0).toList();
    if (priceEntries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          isGerman ? 'KRAFTSTOFFPREISE' : 'PREZZI CARBURANTE',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: priceEntries.map((entry) {
              final fuelName = entry.key;
              final fuel = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          fuelName.toLowerCase().contains('diesel')
                              ? Icons.local_gas_station_rounded
                              : Icons.ev_station_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          fuelName,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${fuel.price.toStringAsFixed(3)} €',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          isGerman ? 'WARNUNGEN' : 'AVVISI',
          style: TextStyle(
            color: theme.colorScheme.error,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...area.events.map((event) {
          final text = event.title.isNotEmpty ? event.title : event.description;
          final date = event.createdAt ?? '';
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_rounded, size: 20, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date.isNotEmpty ? '$text ($date)' : text,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildServicesSection(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          isGerman ? 'DIENSTLEISTUNGEN' : 'SERVIZI',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: area.services.map((service) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getServiceIcon(service.name),
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    service.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('wifi') || name.contains('wireless')) return Icons.wifi_rounded;
    if (name.contains('food') || name.contains('ristorante') || name.contains('restaurant')) return Icons.restaurant_rounded;
    if (name.contains('shop') || name.contains('negozio') || name.contains('geschäft')) return Icons.shopping_bag_rounded;
    if (name.contains('wc') || name.contains('toilet')) return Icons.wc_rounded;
    if (name.contains('shower') || name.contains('doccia')) return Icons.shower_rounded;
    if (name.contains('playground') || name.contains('bambini')) return Icons.child_care_rounded;
    if (name.contains('hotel') || name.contains('berth') || name.contains('parcheggio camper')) return Icons.hotel_rounded;
    if (name.contains('laundry') || name.contains('lavaggio')) return Icons.local_laundry_service_rounded;
    if (name.contains('atm') || name.contains('bancomat')) return Icons.atm_rounded;
    if (name.contains('car wash') || name.contains('autolavaggio')) return Icons.local_car_wash_rounded;
    return Icons.check_circle_outline_rounded;
  }

  Widget _infoRow(ThemeData theme, IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandsSection(ThemeData theme) {
    final fuelBrand = area.fuelBrand;
    final foodBrands = area.foodBrands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          isGerman ? 'MARKEN' : 'MARCHI',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // Fuel brand
        if (fuelBrand.isNotEmpty)
          _buildBrandCard(
            theme,
            fuelBrand,
            Icons.local_gas_station_rounded,
            isGerman ? 'Treibstoff' : 'Carburante',
            true,
          ),

        // Food brands
        ...foodBrands.map((brand) => _buildBrandCard(
              theme,
              brand,
              Icons.restaurant_rounded,
              isGerman ? 'Gastronomie' : 'Ristorazione',
              false,
            )),
      ],
    );
  }

  Widget _buildBrandCard(ThemeData theme, String brandName, IconData fallbackIcon, String label, bool isFuel) {
    final logoUrl = BrandLogos.getLogoUrl(brandName);
    final localLogoPath = BrandLogos.getLocalLogoPath(brandName);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(8),
            child: _buildBrandLogo(logoUrl, localLogoPath, fallbackIcon, theme),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  brandName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandLogo(String? logoUrl, String? localLogoPath, IconData fallbackIcon, ThemeData theme) {
    // Try network image first
    if (logoUrl != null) {
      return Image.network(
        logoUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)));
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local asset
          if (localLogoPath != null) {
            return Image.asset(localLogoPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: theme.colorScheme.primary, size: 24));
          }
          return Icon(fallbackIcon, color: theme.colorScheme.primary, size: 24);
        },
      );
    }
    // Try local asset
    if (localLogoPath != null) {
      return Image.asset(localLogoPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: theme.colorScheme.primary, size: 24));
    }
    // Fallback to icon
    return Icon(fallbackIcon, color: theme.colorScheme.primary, size: 24);
  }
}
