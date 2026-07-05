import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../core/services/runtime_localizations.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_page.dart';
import '../../features/auth/screens/register_page.dart';
import '../providers/theme_provider.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../features/favorites/screens/favorites_page.dart';


class DashboardFeed extends StatelessWidget {
  final VoidCallback onOpenMap;

  const DashboardFeed({
    super.key,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final userName = (user?.nickname != null) ? user!.nickname! : (user?.email != null ? user!.email.split('@')[0] : 'Viaggiatore');

    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor, // Sfondo base
      ),
      child: CustomScrollView(
        slivers: [
          // Spacer in alto (mantiene margin) - rimosso SliverAppBar per evitare colore blu allo scroll
          SliverToBoxAdapter(child: SizedBox(height: kToolbarHeight)),

          // Benvenuto Header (aggiunta spaziatura superiore 100px)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top:65, left:24.0, right:24.0, bottom:12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: RuntimeLocalizations.t(context, 'greeting', params: {'name': ''}).split('{name}').first, // 'Ciao, '
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                        TextSpan(
                          text: authProvider.isAuthenticated ? userName : RuntimeLocalizations.t(context, 'guest'),
                          style: GoogleFonts.syne(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    RuntimeLocalizations.t(context, 'where_to_go_today'),
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Hero Card: Esplora la Mappa
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: GestureDetector(
                onTap: onOpenMap, 
                child: GlassmorphicContainer(
                  width: double.infinity,
                  height: 160,
                  borderRadius: 24,
                  blur: 20,
                  alignment: Alignment.center,
                  border: 0, 
                  linearGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6C63FF).withOpacity(0.8),
                      Color(0xFF3F3D56).withOpacity(0.9),
                    ],
                  ),
                  borderGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white24, Colors.white10],
                  ),
                  child: Stack(
                    children: [
                      // Decorative Background Shape
                      Positioned(
                        right: -20,
                        bottom: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        top: -40,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    RuntimeLocalizations.t(context, 'explore_map'),
                                    style: GoogleFonts.syne(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    RuntimeLocalizations.t(context, 'explore_map_desc'),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.map_rounded, color: Colors.white, size: 36),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sezione Notizie/Status con Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(RuntimeLocalizations.t(context, 'service_status'),
                      style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textColor)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                       Expanded(child: _buildStatusCardGrid(theme, AppLocalizations.of(context)?.trains ?? 'Treni', RuntimeLocalizations.t(context, 'status_regular'), Icons.train, Colors.green)),
                       const SizedBox(width: 12),
                       Expanded(child: _buildStatusCardGrid(theme, AppLocalizations.of(context)?.buses ?? 'Bus', RuntimeLocalizations.t(context, 'status_delays'), Icons.directions_bus, Colors.orange)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

           // Sezione Preferiti Rapidi
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(RuntimeLocalizations.t(context, 'your_favorites'),
                      style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textColor)),
                  if (authProvider.isAuthenticated) TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
                    child: Text(RuntimeLocalizations.t(context, 'see_all')),
                  ),
                ],
              ),
            ),
          ),
          
          if (authProvider.isAuthenticated)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: Consumer<FavoritesProvider>(
              builder: (context, favorites, _) {
                final items = favorites.favoriteStops.take(4).toList();
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                       child: Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Text(RuntimeLocalizations.t(context, 'no_favorites_saved'), style: TextStyle(color: theme.secondaryTextColor)),
                       ),
                    ),
                  );
                }
                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return Container(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                              colors: [theme.surfaceColor, theme.surfaceColor.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight
                           ),
                           borderRadius: BorderRadius.circular(20),
                           boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                           ],
                         ),
                         padding: EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Container(
                               padding: EdgeInsets.all(8),
                               decoration: BoxDecoration(
                                 color: theme.primaryColor.withOpacity(0.1),
                                 borderRadius: BorderRadius.circular(10),
                               ),
                               child: Icon(
                                 item.stopType.name == 'busStop' ? Icons.directions_bus : Icons.train, 
                                 color: theme.primaryColor,
                                 size: 20,
                               ),
                             ),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   item.name,
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold,
                                     fontSize: 16,
                                     color: theme.textColor,
                                   ),
                                 ),
                                 Text(
                                   item.country ?? 'Locale',
                                   style: TextStyle(
                                     fontSize: 12,
                                     color: theme.secondaryTextColor,
                                   ),
                                 ),
                               ],
                             ),
                           ],
                         ),
                      );
                    },
                    childCount: items.length,
                  ),
                );
              },
            ),
          ) else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GlassmorphicContainer(
                   width: double.infinity,
                   // increased height to accommodate buttons
                   height: 160,
                   borderRadius: 20,
                   blur: 10,
                   alignment: Alignment.center,
                   border: 1,
                   linearGradient: LinearGradient(colors: [theme.surfaceColor.withOpacity(0.5), theme.surfaceColor.withOpacity(0.2)]),
                   borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.lock_outline, color: theme.secondaryTextColor),
                       const SizedBox(height: 8),
                       Text(RuntimeLocalizations.t(context, 'login_to_see_favorites'), style: TextStyle(color: theme.secondaryTextColor)),
                       const SizedBox(height: 16),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           ElevatedButton(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: theme.primaryColor,
                               foregroundColor: theme.textColor, // ensure contrast
                             ),
                             onPressed: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (_) => const LoginPage()),
                               );
                             },
                             child: Text(RuntimeLocalizations.t(context, 'login')),
                           ),
                           const SizedBox(width: 12),
                           OutlinedButton(
                             style: OutlinedButton.styleFrom(
                               foregroundColor: theme.primaryColor,
                               side: BorderSide(color: theme.primaryColor),
                             ),
                             onPressed: () {
                               Navigator.push(
                                 context,
                                   MaterialPageRoute(builder: (_) => const RegisterPage()),
                               );
                             },
                                 child: Text(RuntimeLocalizations.t(context, 'register')),
                           ),
                         ],
                       ),
                     ],
                   ),
                ),
              ),
            ),

           const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildStatusCardGrid(ThemeProvider theme, String title, String status, IconData icon, Color statusColor) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          )
        ],
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: statusColor, size: 24),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(status, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          )
        ],
      ),
    );
  }
}
