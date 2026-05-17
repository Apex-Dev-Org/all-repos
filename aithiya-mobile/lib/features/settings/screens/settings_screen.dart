import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/locale_provider.dart';
import '../../../shared/widgets/background_scaffold.dart';
import '../../../shared/widgets/branded_input_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../subscription/providers/subscription_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showEditNameDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final auth = context.read<AuthProvider>();
    final initial = auth.user?.userMetadata?['full_name'] as String? ?? '';

    final ok = await showBrandedInputDialog(
      context: context,
      title: l10n.settingsEditProfileDialogTitle,
      subtitle: l10n.settingsEditNameSubtitle,
      fields: [
        BrandedDialogField(
          labelText: l10n.fieldLabelFullName,
          hintText: l10n.displayNameOptionalLabel,
          initialValue: initial,
          prefixIcon: Icons.person_outline,
          keyboardType: TextInputType.name,
        ),
      ],
      primaryLabel: l10n.dialogSave,
      cancelLabel: l10n.dialogCancel,
      onSubmit: (values) async {
        await auth.updateDisplayName(values[0].trim());
        return auth.errorMessage;
      },
    );
    if (!context.mounted || ok != true) return;
  }

  Future<void> _showResetPasswordDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final auth = context.read<AuthProvider>();
    final initialEmail = auth.user?.email ?? '';

    final ok = await showBrandedInputDialog(
      context: context,
      title: l10n.loginForgotPasswordDialogTitle,
      subtitle: l10n.settingsResetPasswordDialogSubtitle,
      fields: [
        BrandedDialogField(
          labelText: l10n.fieldLabelEmailAddress,
          hintText: l10n.hintEmailExample,
          initialValue: initialEmail,
          prefixIcon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = v.trim();
            if (t.isEmpty) return l10n.validatorEnterEmail;
            if (!t.contains('@')) return l10n.validatorValidEmail;
            return null;
          },
        ),
      ],
      primaryLabel: l10n.dialogSend,
      cancelLabel: l10n.dialogCancel,
      onSubmit: (values) async {
        await auth.sendPasswordReset(values[0].trim());
        return auth.errorMessage;
      },
    );
    if (!context.mounted || ok != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.loginForgotPasswordSent)));
  }

  String _localizedPlanLabel(
    SubscriptionProvider subscription,
    AppLocalizations l10n,
  ) {
    switch (subscription.tier) {
      case SubscriptionTier.free:
        return l10n.subscriptionTierFree;
      case SubscriptionTier.pro:
        return l10n.subscriptionTierPro;
      case SubscriptionTier.ultra:
        return l10n.subscriptionTierUltra;
    }
  }

  String _localizedStatusLabel(
    SubscriptionProvider subscription,
    AppLocalizations l10n,
  ) {
    switch (subscription.status) {
      case 'active':
        return l10n.subscriptionStatusActive;
      case 'pending':
        return l10n.subscriptionStatusPending;
      case 'on_hold':
        return l10n.subscriptionStatusOnHold;
      case 'cancelled':
        return l10n.subscriptionStatusCancelled;
      case 'expired':
        return l10n.subscriptionStatusExpired;
      case 'failed':
        return l10n.subscriptionStatusFailed;
      default:
        return subscription.tier == SubscriptionTier.free
            ? l10n.subscriptionStatusFreePlan
            : l10n.subscriptionStatusUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();
    final localeProv = context.watch<LocaleProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    final String displayName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email ??
        l10n.accountSignedInFallback;
    final String email = user?.email ?? '';

    return BackgroundScaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: BackButton(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person,
                            size: 44,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: auth.isBusy
                                ? null
                                : () => _showEditNameDialog(context, l10n),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              l10n.settingsEditProfileDialogTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: auth.isBusy
                                ? null
                                : () => _showResetPasswordDialog(context, l10n),
                            icon: Icon(
                              Icons.lock_reset_outlined,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              l10n.settingsResetPassword,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.settingsManageSubscription,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.subscriptionDevToggleSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              sub.isPaid
                                  ? Icons.workspace_premium_outlined
                                  : Icons.account_circle_outlined,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _localizedPlanLabel(sub, l10n),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _localizedStatusLabel(sub, l10n),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (sub.isLoading)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          else
                            IconButton(
                              tooltip: l10n.subscriptionRefreshPlanTooltip,
                              onPressed: () => context
                                  .read<SubscriptionProvider>()
                                  .refresh(),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                        ],
                      ),
                    ),
                    if (sub.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.subscriptionRefreshError,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsLanguageSection,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TogglePill(
                            label: l10n.languageSinhala,
                            isSelected: localeProv.preference == 'si',
                            onTap: () => localeProv.setPreference('si'),
                          ),
                          const SizedBox(width: 12),
                          _TogglePill(
                            label: l10n.languageEnglish,
                            isSelected: localeProv.preference == 'en',
                            onTap: () => localeProv.setPreference('en'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.error.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: auth.isBusy
                    ? null
                    : () async {
                        await auth.signOut();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: auth.isBusy
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onError,
                        ),
                      )
                    : Text(
                        l10n.settingsSignOut,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      elevation: isSelected ? 2 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
