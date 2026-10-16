import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shell/app_shell.dart';
import '../../state/account_controller.dart';
import '../../widgets/page_container.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _profileForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _authForm = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _countryCode = TextEditingController();
  final TextEditingController _makes = TextEditingController();
  final TextEditingController _bodyTypes = TextEditingController();
  final TextEditingController _fuelTypes = TextEditingController();
  final TextEditingController _minBudget = TextEditingController();
  final TextEditingController _maxBudget = TextEditingController();
  final TextEditingController _authName = TextEditingController();
  final TextEditingController _authEmail = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late final AccountController _account;
  bool _registering = false;
  bool _loadingPreferences = false;
  bool _savingPreferences = false;
  String _transmission = 'any';
  String? _preferenceError;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _account = context.read<AccountController>()..addListener(_accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _accountChanged());
  }

  @override
  void dispose() {
    _account.removeListener(_accountChanged);
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _email,
      _phone,
      _city,
      _countryCode,
      _makes,
      _bodyTypes,
      _fuelTypes,
      _minBudget,
      _maxBudget,
      _authName,
      _authEmail,
      _password,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _accountChanged() {
    if (!mounted) return;
    final Map<String, dynamic>? profile = _account.profile;
    final String? userId = profile?['id'] as String?;
    if (userId == _loadedUserId) return;
    _loadedUserId = userId;
    if (profile == null) {
      _name.clear();
      _email.clear();
      _phone.clear();
      _city.clear();
      _countryCode.clear();
      _makes.clear();
      _bodyTypes.clear();
      _fuelTypes.clear();
      _minBudget.clear();
      _maxBudget.clear();
      _transmission = 'any';
      setState(() => _preferenceError = null);
      return;
    }
    _name.text = profile['fullName'] as String? ?? '';
    _email.text = profile['email'] as String? ?? '';
    _phone.text = profile['phone'] as String? ?? '';
    _city.text = profile['city'] as String? ?? '';
    _countryCode.text = profile['countryCode'] as String? ?? '';
    setState(() => _preferenceError = null);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loadingPreferences = true);
    try {
      final Map<String, dynamic> envelope = await context.read<ApiClient>().getJson('/interests');
      final Object? raw = envelope['data'];
      if (raw is Map<String, dynamic> && mounted) {
        final Map<String, dynamic> budget = raw['budget'] is Map<String, dynamic>
            ? raw['budget'] as Map<String, dynamic>
            : <String, dynamic>{};
        _makes.text = _joinValues(raw['makes']);
        _bodyTypes.text = _joinValues(raw['bodyTypes']);
        _fuelTypes.text = _joinValues(raw['fuelTypes']);
        _minBudget.text = _stringValue(budget['min']);
        _maxBudget.text = _stringValue(budget['max']);
        _transmission = raw['transmission'] as String? ?? 'any';
      }
    } catch (_) {
      if (mounted) setState(() => _preferenceError = 'Preferences could not be loaded. Retry by reopening Profile.');
    } finally {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  String _joinValues(Object? value) => value is List ? value.join(', ') : '';
  String _stringValue(Object? value) => value == null ? '' : '$value';

  Future<void> _submitAuth() async {
    if (!(_authForm.currentState?.validate() ?? false)) return;
    final bool success = _registering
        ? await _account.register(
            fullName: _authName.text,
            email: _authEmail.text,
            password: _password.text,
          )
        : await _account.signIn(email: _authEmail.text, password: _password.text);
    if (success && mounted) {
      _password.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are signed in.')));
    }
  }

  Future<void> _saveProfile() async {
    if (!(_profileForm.currentState?.validate() ?? false)) return;
    final bool saved = await _account.updateProfile(<String, dynamic>{
      'fullName': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'city': _city.text.trim(),
      'countryCode': _countryCode.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? 'Profile saved.' : _account.errorMessage ?? 'Profile could not be saved.')),
    );
  }

  List<String> _splitValues(String text) => <String>{
    for (final String value in text.split(','))
      if (value.trim().isNotEmpty) value.trim(),
  }.toList(growable: false);

  Future<void> _savePreferences() async {
    final int? min = _minBudget.text.trim().isEmpty ? null : int.tryParse(_minBudget.text.trim());
    final int? max = _maxBudget.text.trim().isEmpty ? null : int.tryParse(_maxBudget.text.trim());
    if ((_minBudget.text.trim().isNotEmpty && min == null) ||
        (_maxBudget.text.trim().isNotEmpty && max == null)) {
      setState(() => _preferenceError = 'Enter a whole number for each budget amount.');
      return;
    }
    if (min != null && max != null && min > max) {
      setState(() => _preferenceError = 'Maximum budget must be at least the minimum budget.');
      return;
    }

    setState(() {
      _savingPreferences = true;
      _preferenceError = null;
    });
    try {
      await context.read<ApiClient>().putJson(
        '/interests',
        body: <String, dynamic>{
          'budget': <String, dynamic>{
            if (min case final int budgetMin) 'min': budgetMin,
            if (max case final int budgetMax) 'max': budgetMax,
            'currency': 'INR',
          },
          'makes': _splitValues(_makes.text),
          'bodyTypes': _splitValues(_bodyTypes.text),
          'fuelTypes': _splitValues(_fuelTypes.text),
          'transmission': _transmission,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences saved.')));
    } catch (_) {
      if (mounted) setState(() => _preferenceError = 'Preferences could not be saved. Check the values and try again.');
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: PageContainer(
        child: Consumer<AccountController>(
          builder: (BuildContext context, AccountController account, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ShellAppBar(
                overline: 'Carvexa AI',
                title: account.isAuthenticated ? 'Your profile' : 'Welcome back',
                subtitle: account.isAuthenticated
                    ? 'Your details and buying preferences'
                    : 'Sign in to save vehicles and get tailored guidance',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!account.isRestored)
                const Center(child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: CircularProgressIndicator(),
                ))
              else if (account.isAuthenticated)
                _signedInContent(account)
              else
                _authContent(account),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'CARVEXA AI',
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(color: context.brand.textTertiary, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authContent(AccountController account) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
    child: Form(
      key: _authForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_registering) ...<Widget>[
            _field(_authName, 'Full name', validator: (String? value) =>
                (value == null || value.trim().length < 2) ? 'Enter your name.' : null),
            const SizedBox(height: AppSpacing.md),
          ],
          _field(_authEmail, 'Email', keyboardType: TextInputType.emailAddress, validator: (String? value) =>
              value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                  ? 'Enter a valid email address.'
                  : null),
          const SizedBox(height: AppSpacing.md),
          _field(_password, 'Password', obscureText: true, validator: (String? value) =>
              value == null || value.length < (_registering ? 10 : 1)
                  ? _registering ? 'Use at least 10 characters.' : 'Enter your password.'
                  : null),
          if (account.errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(account.errorMessage!, style: context.text.bodySmall?.copyWith(color: context.brand.danger)),
          ],
          const SizedBox(height: AppSpacing.lg),
          PremiumButton(
            label: _registering ? 'Create account' : 'Sign in',
            loading: account.isBusy,
            onPressed: account.isBusy ? null : _submitAuth,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: account.isBusy ? null : () => setState(() {
              _registering = !_registering;
              account.clearError();
            }),
            child: Text(_registering ? 'I already have an account' : 'Create a new account'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your password is protected by the Carvexa server and is never stored in this app.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.brand.textTertiary),
          ),
        ],
      ),
    ),
  );

  Widget _signedInContent(AccountController account) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: 'Profile details'),
        Form(
          key: _profileForm,
          child: Column(
            children: <Widget>[
              _field(_name, 'Full name', validator: (String? value) =>
                  (value == null || value.trim().length < 2) ? 'Enter your name.' : null),
              const SizedBox(height: AppSpacing.md),
              _field(_email, 'Email', keyboardType: TextInputType.emailAddress, validator: (String? value) =>
                  value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                      ? 'Enter a valid email address.'
                      : null),
              const SizedBox(height: AppSpacing.md),
              _field(_phone, 'Phone (optional)', keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.md),
              _field(_city, 'City (optional)'),
              const SizedBox(height: AppSpacing.md),
              _field(_countryCode, 'Country code (optional)', maxLength: 2),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumButton(label: 'Save profile', loading: account.isBusy, onPressed: _saveProfile),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: <Widget>[
            Expanded(child: SectionHeader(title: 'Buying preferences')),
            if (_loadingPreferences)
              const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        Text('Comma separate lists. Budget uses Indian rupees.', style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.md),
        _field(_makes, 'Preferred brands'),
        const SizedBox(height: AppSpacing.md),
        _field(_bodyTypes, 'Body types'),
        const SizedBox(height: AppSpacing.md),
        _field(_fuelTypes, 'Fuel types'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(child: _field(_minBudget, 'Min budget', keyboardType: TextInputType.number)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _field(_maxBudget, 'Max budget', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: _transmission,
          decoration: const InputDecoration(labelText: 'Transmission'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'any', child: Text('Any transmission')),
            DropdownMenuItem(value: 'automatic', child: Text('Automatic')),
            DropdownMenuItem(value: 'manual', child: Text('Manual')),
          ],
          onChanged: (String? value) => setState(() => _transmission = value ?? 'any'),
        ),
        if (_preferenceError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(_preferenceError!, style: context.text.bodySmall?.copyWith(color: context.brand.danger)),
        ],
        const SizedBox(height: AppSpacing.md),
        PremiumButton(
          label: 'Save preferences',
          loading: _savingPreferences,
          onPressed: _savingPreferences ? null : _savePreferences,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.ai),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Ask Carvexa AI for recommendations'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: account.isBusy ? null : account.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    int? maxLength,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    obscureText: obscureText,
    maxLength: maxLength,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(labelText: label),
  );
}
