import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_service.dart';

class HisabSaathiApp extends StatelessWidget {
  const HisabSaathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService(Supabase.instance.client);
    return MaterialApp(
      title: 'HisabSaathi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6B4F)),
        useMaterial3: true,
      ),
      home: AuthGate(auth: auth),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({required this.auth, super.key});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: auth.authStateChanges,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        auth.session,
      ),
      builder: (context, snapshot) {
        if (snapshot.data?.session == null) {
          return SignInPage(auth: auth);
        }
        return AuthenticatedShell(auth: auth);
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({required this.auth, super.key});

  final AuthService auth;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();
  bool createAccount = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (createAccount) {
        await widget.auth.signUp(
          email: email.text,
          password: password.text,
          displayName: displayName.text,
        );
      } else {
        await widget.auth.signIn(
          email: email.text,
          password: password.text,
        );
      }
    } on AuthException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'HisabSaathi',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(createAccount ? 'Create your account' : 'Sign in'),
                  if (createAccount)
                    TextField(
                      controller: displayName,
                      decoration:
                          const InputDecoration(labelText: 'Display name'),
                    ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy
                        ? 'Please wait…'
                        : createAccount
                            ? 'Create account'
                            : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              createAccount = !createAccount;
                              error = null;
                            }),
                    child: Text(createAccount
                        ? 'Already have an account? Sign in'
                        : 'New to HisabSaathi? Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthenticatedShell extends StatelessWidget {
  const AuthenticatedShell({required this.auth, super.key});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.session?.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HisabSaathi'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Signed in as ${user?.email ?? 'account'}.\n'
          'Shop setup and the local-first dashboard are next phases.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}