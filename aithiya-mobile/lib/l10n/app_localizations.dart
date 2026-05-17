import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Aithiya'**
  String get appTitle;

  /// No description provided for @loginBrandTitle.
  ///
  /// In en, this message translates to:
  /// **'Aithiya'**
  String get loginBrandTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sri Lankan legal information assistant'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @validatorEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get validatorEnterEmail;

  /// No description provided for @validatorValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validatorValidEmail;

  /// No description provided for @validatorEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get validatorEnterPassword;

  /// No description provided for @validatorChoosePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get validatorChoosePassword;

  /// No description provided for @validatorPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get validatorPasswordMinLength;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccountLink;

  /// No description provided for @signUpAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpAppBarTitle;

  /// No description provided for @displayNameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get displayNameOptionalLabel;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @appearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSinhala.
  ///
  /// In en, this message translates to:
  /// **'සිංහල'**
  String get languageSinhala;

  /// No description provided for @disclaimerSection.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimerSection;

  /// No description provided for @accountSignedInFallback.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedInFallback;

  /// No description provided for @accountSubtitleMvp.
  ///
  /// In en, this message translates to:
  /// **'Sri Lankan AI legal assistant (MVP)'**
  String get accountSubtitleMvp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @chatTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitleDefault;

  /// No description provided for @chatEmptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Describe your situation in plain language. Answers in this build use mock citations for UI only.'**
  String get chatEmptyStateBody;

  /// No description provided for @chatHintAskLegalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a legal question…'**
  String get chatHintAskLegalQuestion;

  /// No description provided for @chatListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get chatListening;

  /// No description provided for @voiceInputTooltip.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceInputTooltip;

  /// No description provided for @voiceTranscriptionErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not transcribe audio. Try again.'**
  String get voiceTranscriptionErrorGeneric;

  /// No description provided for @voicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice input.'**
  String get voicePermissionDenied;

  /// No description provided for @voiceMissingApiKey.
  ///
  /// In en, this message translates to:
  /// **'Voice input is not configured (missing API key).'**
  String get voiceMissingApiKey;

  /// No description provided for @voiceEmptyTranscript.
  ///
  /// In en, this message translates to:
  /// **'No speech was detected. Try again.'**
  String get voiceEmptyTranscript;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @citationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Citations'**
  String get citationsLabel;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @legalDisclaimerFull.
  ///
  /// In en, this message translates to:
  /// **'This tool provides legal information for educational purposes and does not constitute official legal advice. Always consult a qualified Sri Lankan attorney.'**
  String get legalDisclaimerFull;

  /// No description provided for @attachTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get attachTooltip;

  /// No description provided for @attachSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachSheetTitle;

  /// No description provided for @attachFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachFromCamera;

  /// No description provided for @attachFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get attachFromGallery;

  /// No description provided for @attachDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get attachDocument;

  /// No description provided for @attachmentLimitReachedFree.
  ///
  /// In en, this message translates to:
  /// **'Free plan: one attachment per message. Upgrade to a paid plan for up to five.'**
  String get attachmentLimitReachedFree;

  /// No description provided for @attachmentLimitReachedPro.
  ///
  /// In en, this message translates to:
  /// **'You can attach up to five files per message.'**
  String get attachmentLimitReachedPro;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Each file must be 25 MB or smaller.'**
  String get attachmentTooLarge;

  /// No description provided for @attachmentPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not pick attachment. Try again.'**
  String get attachmentPickFailed;

  /// No description provided for @attachmentNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera detected on this device. Try Gallery, or use this app on your phone.'**
  String get attachmentNoCamera;

  /// No description provided for @attachmentPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview not available in mock mode.'**
  String get attachmentPreviewUnavailable;

  /// No description provided for @subscriptionSection.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionSection;

  /// No description provided for @subscriptionTierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionTierFree;

  /// No description provided for @subscriptionTierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get subscriptionTierPro;

  /// No description provided for @subscriptionTierUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get subscriptionTierUltra;

  /// No description provided for @subscriptionStatusFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get subscriptionStatusFreePlan;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get subscriptionStatusPending;

  /// No description provided for @subscriptionStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get subscriptionStatusOnHold;

  /// No description provided for @subscriptionStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get subscriptionStatusCancelled;

  /// No description provided for @subscriptionStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get subscriptionStatusExpired;

  /// No description provided for @subscriptionStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get subscriptionStatusFailed;

  /// No description provided for @subscriptionStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get subscriptionStatusUnknown;

  /// No description provided for @subscriptionRefreshPlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh plan'**
  String get subscriptionRefreshPlanTooltip;

  /// No description provided for @subscriptionRefreshError.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh billing status. Showing the last synced plan.'**
  String get subscriptionRefreshError;

  /// No description provided for @subscriptionDevToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your current plan is synced from billing after checkout is confirmed.'**
  String get subscriptionDevToggleSubtitle;

  /// No description provided for @welcomeChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR LANGUAGE'**
  String get welcomeChooseLanguage;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeFooterTagline.
  ///
  /// In en, this message translates to:
  /// **'Private · Confidential · AI-powered guidance'**
  String get welcomeFooterTagline;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'FORGOT PASSWORD?'**
  String get loginForgotPassword;

  /// No description provided for @loginForgotPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get loginForgotPasswordDialogTitle;

  /// No description provided for @loginForgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get loginForgotPasswordSent;

  /// No description provided for @signupHeading.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupHeading;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your details to start scanning.'**
  String get signupSubtitle;

  /// No description provided for @signupVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to verify it before signing in.'**
  String get signupVerifyEmail;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @validatorPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validatorPasswordsDontMatch;

  /// No description provided for @chatHintDescribeWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened…'**
  String get chatHintDescribeWhatHappened;

  /// No description provided for @drawerRecentChats.
  ///
  /// In en, this message translates to:
  /// **'Recent Chats'**
  String get drawerRecentChats;

  /// No description provided for @drawerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a chat'**
  String get drawerSearchHint;

  /// No description provided for @chatHistoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatHistoryDelete;

  /// No description provided for @chatHistoryDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get chatHistoryDeleteConfirmTitle;

  /// No description provided for @chatHistoryDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This conversation will be permanently removed. You can\'t undo this.'**
  String get chatHistoryDeleteConfirmBody;

  /// No description provided for @chatHistoryDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatHistoryDeleteSuccess;

  /// No description provided for @chatHistoryDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete chat. Try again.'**
  String get chatHistoryDeleteError;

  /// No description provided for @dialogDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dialogDelete;

  /// No description provided for @chatHistoryMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatHistoryMoreActions;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsEditProfileDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get settingsEditProfileDialogTitle;

  /// No description provided for @settingsEditNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your display name.'**
  String get settingsEditNameSubtitle;

  /// No description provided for @settingsResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get settingsResetPassword;

  /// No description provided for @settingsResetPasswordDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email a reset link to this address.'**
  String get settingsResetPasswordDialogSubtitle;

  /// No description provided for @settingsManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get settingsManageSubscription;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsThemeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeSection;

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @dialogSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get dialogSend;

  /// No description provided for @dialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dialogSave;

  /// No description provided for @loginPromoAskLegal.
  ///
  /// In en, this message translates to:
  /// **'Ask any legal question'**
  String get loginPromoAskLegal;

  /// No description provided for @fieldLabelEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'EMAIL ADDRESS'**
  String get fieldLabelEmailAddress;

  /// No description provided for @fieldLabelPassword.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get fieldLabelPassword;

  /// No description provided for @fieldLabelFullName.
  ///
  /// In en, this message translates to:
  /// **'FULL NAME'**
  String get fieldLabelFullName;

  /// No description provided for @fieldLabelConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get fieldLabelConfirmPassword;

  /// No description provided for @orDividerUpper.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDividerUpper;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginNoAccount;

  /// No description provided for @hintEmailExample.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get hintEmailExample;

  /// No description provided for @hintPasswordMask.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get hintPasswordMask;

  /// No description provided for @hintConfirmPasswordMask.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get hintConfirmPasswordMask;

  /// Mock lead-in prefix prepended to the assistant's reply when the user sent attachments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{Considering 1 attachment: } other{Considering {count} attachments: }}'**
  String mockAttachmentIntro(int count);

  /// Mock assistant reply about rent / tenancy. UI only.
  ///
  /// In en, this message translates to:
  /// **'Tenancy disputes in Sri Lanka are governed primarily by the Rent Act and related case law. A landlord generally must give reasonable written notice before terminating a tenancy, and unilateral eviction without a court order may be unlawful. Keep records of payments, communications, and the tenancy agreement, and consider mediation before litigation.'**
  String get mockReplyRent;

  /// Mock citation accompanying the rent reply.
  ///
  /// In en, this message translates to:
  /// **'Rent Act, No. 7 of 1972 (Sri Lanka) — illustrative citation only.'**
  String get mockCitationRent;

  /// Mock assistant reply about employment / labour. UI only.
  ///
  /// In en, this message translates to:
  /// **'Employment matters in Sri Lanka are mainly covered by the Industrial Disputes Act, the Shop and Office Employees Act, and the Termination of Employment of Workmen (Special Provisions) Act. Termination of permanent workmen typically requires either the worker\'s written consent or prior approval from the Commissioner of Labour. Preserve your appointment letter, payslips, and any termination notice.'**
  String get mockReplyEmployment;

  /// Mock citation accompanying the employment reply.
  ///
  /// In en, this message translates to:
  /// **'Termination of Employment of Workmen (Special Provisions) Act, No. 45 of 1971 — illustrative citation only.'**
  String get mockCitationEmployment;

  /// Mock assistant reply about traffic / motor offences. UI only.
  ///
  /// In en, this message translates to:
  /// **'Driving offences in Sri Lanka are addressed by the Motor Traffic Act and associated regulations. Penalties may include fines, demerit points, or licence suspension depending on the offence. If you receive a charge sheet, note the offence code, the issuing officer, and any witnesses, and consider consulting an attorney before pleading.'**
  String get mockReplyTraffic;

  /// Mock citation accompanying the traffic reply.
  ///
  /// In en, this message translates to:
  /// **'Motor Traffic Act, No. 14 of 1951 (as amended) — illustrative citation only.'**
  String get mockCitationTraffic;

  /// Mock assistant fallback reply when no keyword matches. UI only.
  ///
  /// In en, this message translates to:
  /// **'I can share general information about Sri Lankan law, but this build returns mock responses for UI demonstration only. For an actual legal issue, please consult a qualified attorney admitted in Sri Lanka.'**
  String get mockReplyGeneric;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
