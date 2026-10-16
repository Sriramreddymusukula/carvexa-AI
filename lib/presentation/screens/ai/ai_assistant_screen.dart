import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/car_preview.dart';
import '../../../data/services/car_catalog_dto.dart';
import '../../motion/drive_in_reveal.dart';
import '../../state/account_controller.dart';
import '../../widgets/automotive_loader.dart';
import '../../widgets/car_card.dart';
import '../../widgets/state_views.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
    this.initialVehicleIds = const <String>[],
  });

  final List<String> initialVehicleIds;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      fromUser: false,
      text: 'I’m Carvexa AI. Ask about a vehicle, compare models, or get help choosing. Catalog details are used when available; I’ll call out anything the catalog does not publish.',
    ),
  ];
  bool _sending = false;
  String? _error;
  Future<void> Function()? _retryAction;
  late final List<String> _vehicleIds;

  @override
  void initState() {
    super.initState();
    _vehicleIds = widget.initialVehicleIds.toSet().toList(growable: false);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? supplied]) async {
    final String text = (supplied ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final bool alreadyInTranscript =
        supplied != null &&
        _messages.isNotEmpty &&
        _messages.last.fromUser &&
        _messages.last.text == text;

    setState(() {
      _sending = true;
      _error = null;
      _retryAction = null;
      if (!alreadyInTranscript) {
        _messages.add(_ChatMessage(fromUser: true, text: text));
      }
      _input.clear();
    });
    _scrollToEnd();

    try {
      final Map<String, dynamic>
      envelope = await context.read<ApiClient>().postJson(
        '/ai/chat',
        timeout: const Duration(seconds: 45),
        body: <String, dynamic>{
          // The backend accepts at most 16 turns. Keep the latest context so
          // longer chats continue working, and omit the UI-only welcome copy.
          'messages': _messages
              .skip(1)
              .where((_ChatMessage message) => message.text.trim().isNotEmpty)
              .toList(growable: false)
              .reversed
              .take(16)
              .toList(growable: false)
              .reversed
              .map(
                (_ChatMessage message) => <String, dynamic>{
                  'role': message.fromUser ? 'user' : 'model',
                  'text': message.text,
                },
              )
              .toList(growable: false),
          'vehicleIds': _vehicleIds,
        },
      );
      final Object? data = envelope['data'];
      if (data is! Map<String, dynamic> || data['reply'] is! String) {
        throw const FormatException('AI response was incomplete');
      }
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(fromUser: false, text: data['reply'] as String),
        ),
      );
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppFailure ? error.message : 'Carvexa AI could not answer right now. Check your connection and retry.';
        _retryAction = () => _send(text);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recommend() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _retryAction = null;
    });
    try {
      final Map<String, dynamic> envelope = await context
          .read<ApiClient>()
          .postJson(
            '/ai/recommendations',
            timeout: const Duration(seconds: 45),
            body: const <String, dynamic>{},
          );
      final Object? data = envelope['data'];
      if (data is! Map<String, dynamic> || data['explanation'] is! String) {
        throw const FormatException('Recommendation response was incomplete');
      }
      final Object? rawVehicles = data['vehicles'];
      final List<CarPreview> vehicles = rawVehicles is List
          ? rawVehicles
                .whereType<Map<String, dynamic>>()
                .map(CarCatalogDto.car)
                .whereType<CarPreview>()
                .toList(growable: false)
          : const <CarPreview>[];
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            fromUser: false,
            text: data['explanation'] as String,
            vehicles: vehicles,
          ),
        ),
      );
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Recommendations could not be loaded. Save your preferences and retry.';
        _retryAction = _recommend;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AccountController account = context.watch<AccountController>();
    return Scaffold(
      body: SafeArea(
        child: !account.isRestored
            ? const Center(child: AutomotiveLoader())
            : !account.isAuthenticated
            ? _signInPrompt(context)
            : Column(
                children: <Widget>[
                  _header(context),
                  Expanded(child: _conversation(context)),
                  _composer(context),
                ],
              ),
      ),
    );
  }

  Widget _signInPrompt(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.pageGutter),
      child: EmptyState(
        title: 'Meet Carvexa AI',
        message: 'Sign in to ask questions and get recommendations shaped by your saved preferences.',
        icon: Icons.auto_awesome_rounded,
        actionLabel: 'Sign in',
        onAction: () => context.push(AppRoutes.profile),
      ),
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: <Widget>[
        IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.brand.surfaceRaised,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: context.brand.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: context.brand.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'CARVEXA AI',
                style: context.text.labelSmall?.copyWith(
                  color: context.brand.accent,
                  letterSpacing: 1.4,
                ),
              ),
              Text('Your automotive guide', style: context.text.titleMedium),
            ],
          ),
        ),
        IconButton(
          onPressed: _sending ? null : _recommend,
          tooltip: 'Personalized recommendations',
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
  );

  Widget _conversation(BuildContext context) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.pageGutter,
      AppSpacing.md,
      AppSpacing.pageGutter,
      AppSpacing.md,
    ),
    itemCount: _messages.length + (_sending ? 1 : 0),
    itemBuilder: (BuildContext context, int index) {
      if (index == _messages.length) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AutomotiveLoader(size: 22, strokeWidth: 2),
          ),
        );
      }
      final _ChatMessage message = _messages[index];
      return DriveInReveal(
        child: Align(
          alignment: message.fromUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.88,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: message.fromUser
                    ? context.brand.surfaceRaised
                    : context.brand.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: message.fromUser
                      ? context.brand.accent.withValues(alpha: 0.28)
                      : context.brand.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SelectableText(message.text, style: context.text.bodyMedium),
                  for (final CarPreview car in message.vehicles) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    CarCard(
                      car: car,
                      layout: CarCardLayout.horizontal,
                      showSpecs: false,
                      onTap: car.detailAvailable
                          ? () => context.push(AppRoutes.carDetails(car.id))
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _composer(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.brand.surface,
      border: Border(top: BorderSide(color: context.brand.outline)),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom > 0
            ? AppSpacing.sm
            : AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_error != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _error!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.brand.warning,
                    ),
                  ),
                ),
                TextButton(onPressed: _retryAction, child: const Text('Retry')),
              ],
            ),
          if (_messages.length == 1) ...<Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _suggestion(
                    context,
                    'Explain this car',
                    () => _send(
                      'Explain the vehicle details and tell me what information is missing.',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _suggestion(
                    context,
                    'Compare models',
                    () => _send('How should I compare vehicles for my needs?'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _suggestion(context, 'My recommendations', _recommend),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sending ? null : (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask about a car or buying decision',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: _sending ? null : () => _send(),
                tooltip: 'Send message',
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Catalog specifications are shown when available. General guidance is not a substitute for a vehicle inspection.',
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(
              color: context.brand.textTertiary,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _suggestion(BuildContext context, String label, VoidCallback onTap) =>
      ActionChip(label: Text(label), onPressed: _sending ? null : onTap);
}

@immutable
class _ChatMessage {
  const _ChatMessage({
    required this.fromUser,
    required this.text,
    this.vehicles = const <CarPreview>[],
  });

  final bool fromUser;
  final String text;
  final List<CarPreview> vehicles;
}
