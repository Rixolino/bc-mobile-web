import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../../favorites/screens/favorites_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final AuthRepository _authRepository = AuthRepository();
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.security, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                const Text('Cambia Password', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Password Attuale
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Password Attuale',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureOld = !obscureOld),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Nuova Password
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nuova Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Almeno 8 caratteri',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Conferma Password
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Conferma Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  oldPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: _isChangingPassword
                    ? null
                    : () async {
                        // Validazione
                        if (oldPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inserisci la password attuale')),
                          );
                          return;
                        }
                        if (newPasswordController.text.length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La password deve avere almeno 8 caratteri')),
                          );
                          return;
                        }
                        if (newPasswordController.text != confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Le password non coincidono')),
                          );
                          return;
                        }
                        if (oldPasswordController.text == newPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La nuova password deve essere diversa da quella attuale')),
                          );
                          return;
                        }

                        setState(() => _isChangingPassword = true);
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final userId = authProvider.currentUser?.id;

                        if (userId != null) {
                          final success = await _authRepository.updatePassword(
                            userId,
                            oldPasswordController.text,
                            newPasswordController.text,
                          );

                          if (success) {
                            oldPasswordController.dispose();
                            newPasswordController.dispose();
                            confirmPasswordController.dispose();
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password cambiata con successo!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password attuale non corretta'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                        setState(() => _isChangingPassword = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: _isChangingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Aggiorna', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_bus,
                            color: theme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Dashboard',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FavoritesPage(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.favorite,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: 'Preferiti',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          authProvider.logout();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(
                          Icons.logout,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(24.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Welcome Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.primaryColor,
                                theme.primaryColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: const Icon(
                                      Icons.waving_hand,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Benvenuto${user?.nickname != null ? ', ${user!.nickname}' : ''}!',
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Esplora i trasporti pubblici',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Quick Actions
                        Text(
                          'Azioni Rapide',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Cards Grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          children: [
                            _buildActionCard(
                              context,
                              icon: Icons.directions_bus,
                              title: 'Bus',
                              subtitle: 'Trova autobus',
                              color: theme.primaryColor,
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            _buildActionCard(
                              context,
                              icon: Icons.train,
                              title: 'Treni',
                              subtitle: 'Orari treni',
                              color: theme.colorScheme.secondary,
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            _buildActionCard(
                              context,
                              icon: Icons.flight,
                              title: 'Voli',
                              subtitle: 'Informazioni voli',
                              color: Colors.orange,
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            _buildActionCard(
                              context,
                              icon: Icons.map,
                              title: 'Mappa',
                              subtitle: 'Visualizza percorsi',
                              color: Colors.green,
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // User Profile Card
                        Card(
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.surface,
                                  theme.colorScheme.surface.withOpacity(0.8),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                                        ),
                                        child: Icon(
                                          Icons.person_outline,
                                          color: theme.primaryColor,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Il tuo Profilo',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildProfileItem(
                                    context,
                                    icon: Icons.email_outlined,
                                    label: 'Email',
                                    value: user?.email ?? 'N/A',
                                  ),
                                  const SizedBox(height: 16),
                                  if (user?.nickname != null)
                                    _buildProfileItem(
                                      context,
                                      icon: Icons.person_outline,
                                      label: 'Nickname',
                                      value: user!.nickname!,
                                    ),
                                  if (user?.nickname != null) const SizedBox(height: 16),
                                  _buildProfileItem(
                                    context,
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Membro dal',
                                    value: user?.createdAt != null
                                        ? '${user!.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
                                        : 'N/A',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Security Section
                        Text(
                          'Sicurezza',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Card(
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.security, color: Colors.orange),
                            ),
                            title: const Text(
                              'Cambia Password',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text('Modifica la tua password di accesso'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showChangePasswordDialog,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Features Preview
                        Text(
                          'Prossimamente',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.08),
                                theme.colorScheme.primary.withOpacity(0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.lightbulb_outline,
                                  size: 48,
                                  color: theme.colorScheme.primary.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Nuove funzionalità in arrivo!',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Stiamo lavorando per offrirti un\'esperienza ancora migliore con nuove features esclusive.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _buildFeatureChip(context, 'Statistiche'),
                                  _buildFeatureChip(context, 'Avvisi'),
                                  _buildFeatureChip(context, 'Condivisione'),
                                  _buildFeatureChip(context, 'Backup'),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.08),
                color.withOpacity(0.02),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.12),
            theme.colorScheme.primary.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
