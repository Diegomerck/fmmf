import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/finance_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

const String kAppVersion = '3.2.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final storageService = await StorageService.init();
  final authService = AuthService();

  runApp(
    FMMFApp(
      storageService: storageService,
      authService: authService,
    ),
  );
}

class FMMFApp extends StatelessWidget {
  final StorageService storageService;
  final AuthService authService;

  const FMMFApp({
    super.key,
    required this.storageService,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FMMF - Personal Finance Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _AuthGate(
        storageService: storageService,
        authService: authService,
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final StorageService storageService;
  final AuthService authService;

  const _AuthGate({
    required this.storageService,
    required this.authService,
  });

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _syncedUid;
  Future<FinanceProvider>? _syncFuture;

  Future<FinanceProvider> _prepareProviderForUser(User user) async {
    await widget.storageService.attachCloudSync(user);
    return FinanceProvider(widget.storageService);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          if (_syncedUid != null) {
            widget.storageService.detachCloudSync();
            _syncedUid = null;
            _syncFuture = null;
          }
          return AuthScreen(authService: widget.authService);
        }

        if (_syncedUid != user.uid || _syncFuture == null) {
          _syncedUid = user.uid;
          _syncFuture = _prepareProviderForUser(user);
        }

        return FutureBuilder<FinanceProvider>(
          future: _syncFuture,
          builder: (context, providerSnap) {
            if (providerSnap.hasError) {
              return Scaffold(
                backgroundColor: AppTheme.background,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 48, color: AppTheme.alertCoral),
                        const SizedBox(height: 12),
                        const Text(
                          'No se pudo sincronizar tu información con la nube.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${providerSnap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _syncFuture = _prepareProviderForUser(user);
                            });
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (!providerSnap.hasData) {
              return const Scaffold(
                backgroundColor: AppTheme.background,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.emeraldGreen),
                      SizedBox(height: 14),
                      Text(
                        'Sincronizando tus cuentas...',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return HomeScreen(
              provider: providerSnap.data!,
              userEmail: user.email,
              onSignOut: () => widget.authService.signOut(),
            );
          },
        );
      },
    );
  }
}
