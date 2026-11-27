import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final AuthService authService;

  const AuthScreen({super.key, required this.authService});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _mapAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'El correo electrónico no tiene un formato válido.';
        case 'user-disabled':
          return 'Esta cuenta ha sido deshabilitada.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta registrada con este correo.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        case 'popup-closed-by-user':
          return 'Se cerró la ventana de inicio de sesión antes de completar.';
        case 'unauthorized-domain':
          return 'Este dominio aún no está autorizado en Firebase Auth.';
        case 'expired-action-code':
          return 'El enlace o código de recuperación ya expiró. Solicita uno nuevo.';
        case 'invalid-action-code':
          return 'El enlace o código de recuperación no es válido o ya fue usado.';
        default:
          return e.message ?? 'No se pudo iniciar sesión (${e.code}).';
      }
    }
    return 'Ocurrió un error inesperado al autenticar.';
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      if (_isRegisterMode) {
        await widget.authService.registerWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _mapAuthError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await widget.authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _mapAuthError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Escribe tu correo primero para recuperar tu contraseña.';
        _infoMessage = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await widget.authService.sendPasswordResetEmail(email);
      if (mounted) {
        setState(() {
          _infoMessage =
              'Enviamos un correo a $email. Si tu red bloquea el enlace, copia la dirección del enlace del correo y usa "Restablecer con enlace o código".';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _mapAuthError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showInAppResetDialog() async {
    final codeCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    bool obscure = true;
    String? dialogError;

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text(
            'Restablecer contraseña aquí',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Copia el enlace del correo (clic derecho → Copiar dirección del enlace) o pega el código oobCode y escribe tu nueva contraseña.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (dialogError != null) ...[
                  Text(
                    dialogError!,
                    style: const TextStyle(
                        color: AppTheme.alertCoral, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: codeCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Enlace del correo o código',
                    hintText: 'https://...oobCode=... o el código',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Pega el enlace o código del correo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });
                      try {
                        await widget.authService.confirmPasswordReset(
                          codeOrUrl: codeCtrl.text,
                          newPassword: passCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() {
                          submitting = false;
                          dialogError = _mapAuthError(e);
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Guardar contraseña'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
    passCtrl.dispose();

    if (success == true && mounted) {
      setState(() {
        _errorMessage = null;
        _infoMessage =
            'Contraseña actualizada correctamente. Ya puedes iniciar sesión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.emeraldGreen.withOpacity(0.45),
                            ),
                          ),
                          child: const Text(
                            'FMMF',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.emeraldGreen,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRegisterMode ? 'Crea tu cuenta' : 'Inicia sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tu información financiera sincronizada de forma privada en la nube.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.alertCoral.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.alertCoral.withOpacity(0.4)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.alertCoral,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_infoMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.emeraldGreen.withOpacity(0.4)),
                        ),
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(
                            color: AppTheme.emeraldGreen,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.account_circle_outlined, size: 20),
                      label: const Text(
                        'Continuar con Google',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: Colors.white.withOpacity(0.1))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o con correo',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: Colors.white.withOpacity(0.1))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (val) {
                              if (val == null ||
                                  val.trim().isEmpty ||
                                  !val.contains('@')) {
                                return 'Ingresa un correo válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: _isRegisterMode
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submitEmail(),
                          ),
                        ],
                      ),
                    ),
                    if (!_isRegisterMode) ...[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed:
                                _isLoading ? null : _showInAppResetDialog,
                            child: const Text(
                              'Tengo enlace/código',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: const Text(
                              '¿Olvidaste tu contraseña?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _isRegisterMode ? 'Crear cuenta' : 'Entrar',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _errorMessage = null;
                                _infoMessage = null;
                              }),
                      child: Text(
                        _isRegisterMode
                            ? '¿Ya tienes cuenta? Inicia sesión'
                            : '¿No tienes cuenta? Regístrate',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
