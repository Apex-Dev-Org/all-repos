# Aithiya (mobile)

Flutter Android MVP for **Aithiya** — a conversational legal information assistant focused on Sri Lankan law.

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable) and Android tooling.
2. Copy environment template and add your Supabase + backend values:

   ```bash
   cp .env.example .env
   ```

   | Variable | Purpose |
   |----------|---------|
   | `SUPABASE_URL` | Supabase project URL |
   | `SUPABASE_ANON_KEY` | Supabase anon (public) key |
   | `AUTH_REDIRECT_URL` | Supabase OAuth callback URL; default is `aithiya://auth-callback` |
   | `API_BASE_URL` | FastAPI base URL without `/api/v1` (e.g. `http://10.0.2.2:8000` for Android emulator) |
   | `API_V1_PREFIX` | Backend API prefix, defaults to `/api/v1` |
   | `ELEVENLABS_API_KEY` | ElevenLabs API key for chat **voice input** (Speech-to-Text). Prefer proxying via backend in production. |

3. **Supabase Auth**
   - Enable **Email** auth.
   - For immediate login after email/password signup, disable **Confirm email**.
     If **Confirm email** stays enabled, Supabase will create the user without
     returning a session until the email is verified.
   - Enable the **Google** provider in Supabase and paste the Google OAuth client ID / secret there.
   - Add `aithiya://auth-callback` to Supabase Auth **Redirect URLs** for
     OAuth and email confirmation callbacks.

4. Fetch packages and run:

   ```bash
   flutter pub get
   flutter run
   ```

## Building a GitHub release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` — upload this file to a GitHub Release for direct Android downloads.

Release signing: create `android/key.properties` from `android/key.properties.example` and keep the keystore out of git. If `android/key.properties` is missing, local release builds fall back to debug signing so you can still smoke test the APK.

## Project layout

- `lib/main.dart` — `WidgetsFlutterBinding`, `.env` load, `Supabase.initialize`, `runApp`
- `lib/app.dart` — `MultiProvider`, `MaterialApp`, `AuthGate`
- `lib/features/auth/` — Supabase email/password + Supabase Google OAuth sign-in
- `lib/features/chat/` — Chat UI (voice, **file attachments** with camera/gallery/documents), `AttachmentPickerService`, conditional local image thumbnails, and `RemoteChatRepository` for the FastAPI thread/message/chat endpoints
- `lib/features/settings/` — Profile, mock **subscription tier** toggle (attachment limits dev testing), language (English / සිංහල), theme, disclaimer, sign out

The app sends the current Supabase access token as `Authorization: Bearer <token>` and uses `POST /chat` with `multipart/form-data` for prompts and attachments.

## Legal disclaimer

The app surfaces: *"This tool provides legal information for educational purposes and does not constitute official legal advice. Always consult a qualified Sri Lankan attorney."* (see `LegalDisclaimerBanner`).
