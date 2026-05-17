# Aithiya Deployment Checklist

Deploy in this order:

1. `aithiya-backend` to Google Cloud Run.
2. `aithiya-web` to Vercel.
3. `aithiya_mobile` as a GitHub Release APK.

## 1. Backend: Google Cloud Run

Required production environment values are listed in:

```text
aithiya-backend/.env.production.example
```

Suggested Cloud Run command from the backend repo:

```bash
gcloud run deploy aithiya-backend \
  --source . \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars ENV=production,API_V1_PREFIX=/api/v1,SUPABASE_URL=https://your-project.supabase.co,SUPABASE_ANON_KEY=your-anon-key,SUPABASE_SERVICE_ROLE_KEY=your-service-role-key,SUPABASE_JWT_AUDIENCE=authenticated,GEMINI_API_KEY=your-gemini-key,GEMINI_CHAT_MODEL=gemini-2.5-flash,GEMINI_EMBED_MODEL=gemini-embedding-001,GEMINI_EMBED_OUTPUT_DIM=768,CORS_ORIGINS=https://your-web-domain
```

After deploy, copy the Cloud Run service URL. That becomes:

```text
BACKEND_URL=https://your-cloud-run-url
API_BASE_URL=https://your-cloud-run-url
```

## 2. Web: Vercel

Required production environment values are listed in:

```text
aithiya-web/.env.production.example
```

In Vercel:

1. Import the `aithiya-web` GitHub repo as a new project.
2. Keep the framework preset as Next.js.
3. Add these environment variables under Project Settings -> Environment Variables.
4. Deploy production.

```text
NEXT_PUBLIC_APP_URL=https://your-web-domain
BACKEND_URL=https://your-cloud-run-url
API_V1_PREFIX=/api/v1
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
DODO_PAYMENTS_API_KEY=...
DODO_WEBHOOK_SECRET=...
DODO_PAYMENTS_ENVIRONMENT=live_mode
DODO_PAYMENTS_RETURN_URL=https://your-web-domain/settings
DODO_CUSTOMER_PORTAL_RETURN_URL=https://your-web-domain/settings
NEXT_PUBLIC_DODO_PRO_MONTH_ID=...
NEXT_PUBLIC_DODO_PRO_YEAR_ID=...
NEXT_PUBLIC_DODO_ULTRA_MONTH_ID=...
NEXT_PUBLIC_DODO_ULTRA_YEAR_ID=...
```

Keep these blank unless you intentionally want to bypass the web proxy:

```text
NEXT_PUBLIC_API_BASE_URL=
NEXT_PUBLIC_AUTH_TOKEN=
```

Dodo production webhook endpoint:

```text
https://your-web-domain/api/webhook/dodo-payments
```

Supabase Auth redirect URLs:

```text
https://your-web-domain/auth/callback
https://your-web-domain/reset-password
aithiya://auth-callback
```

Google OAuth JavaScript origin:

```text
https://your-web-domain
```

Google OAuth redirect URI:

```text
https://your-project.supabase.co/auth/v1/callback
```

## 3. Mobile: GitHub APK

Required production environment values are listed in:

```text
aithiya_mobile/.env.production.example
```

For release builds, copy production env values into:

```text
aithiya_mobile/.env
```

Use:

```text
API_BASE_URL=https://your-cloud-run-url
API_V1_PREFIX=/api/v1
AUTH_REDIRECT_URL=aithiya://auth-callback
```

Before public APK release, the Android package id is:

```text
com.aithiya.app
```

Android release signing files:

```text
aithiya_mobile/android/key.properties.example
```

Create an upload key:

```bash
cd aithiya_mobile
keytool -genkey -v \
  -keystore android/app/aithiya-upload-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias aithiya-upload
cp android/key.properties.example android/key.properties
```

Then edit `android/key.properties` with the passwords you entered.

Build release APK:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Output:

```text
aithiya_mobile/build/app/outputs/flutter-apk/app-release.apk
```

Create a GitHub release manually:

```bash
gh release create android-v1.0.0 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "Aithiya Android v1.0.0" \
  --notes "Android APK download for Aithiya."
```

Or use the included workflow:

```text
aithiya_mobile/.github/workflows/android-apk-release.yml
```

Required GitHub repo secrets for the workflow:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
API_BASE_URL
ANDROID_KEYSTORE_BASE64
ANDROID_STORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

Create `ANDROID_KEYSTORE_BASE64` from your keystore with:

```bash
base64 -w 0 android/app/aithiya-upload-key.jks
```

Optional GitHub repo variables:

```text
AUTH_REDIRECT_URL=aithiya://auth-callback
API_V1_PREFIX=/api/v1
```

To trigger an APK GitHub Release from your laptop:

```bash
git tag android-v1.0.0
git push origin android-v1.0.0
```

## Final Production Checks

- Backend `/api/v1/health` returns OK from the Cloud Run URL.
- Web login works with email and Google.
- Web chat works against the Cloud Run backend.
- Dodo checkout returns to `/settings`.
- Dodo webhook delivers to `/api/webhook/dodo-payments`.
- Supabase `user_subscriptions` updates after payment.
- Mobile login works.
- Mobile chat works.
- Mobile settings shows the paid plan after the webhook updates Supabase.
