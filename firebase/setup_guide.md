# Firebase Setup Guide

## One-time project setup

1. Create a Firebase project at https://console.firebase.google.com (e.g. `one-tap-fix`).
2. Enable providers in **Authentication → Sign-in method**:
   - Phone (primary for customers/technicians)
   - Email/Password (fallback + admin web panel)
3. Create the database:
   - **Firestore Database** → Create (production mode).
   - **Storage** → Get started (production mode).
4. Register apps:
   - Android app with package id **com.onetapfix.mepconnect**
     (download `google-services.json` → copy into `apps/mobile/android/app/`)
   - iOS app with bundle id **com.onetapfix.mepconnect**
     (download `GoogleService-Info.plist` → copy into `apps/mobile/ios/Runner/`)
   - Web app for the admin panel
     (used by `flutterfire configure` for both apps)
5. Install flutterfire: `dart pub global activate flutterfire_cli`
6. Generate Dart configs (run inside each app folder):
   - `apps/mobile/`:   `flutterfire configure --project <project-id> --platforms android,ios`
   - `apps/admin_web/`: `flutterfire configure --project <project-id> --platforms web`
   - This overwrites `lib/firebase_options.dart` (the committed file is a
     placeholder that must be replaced before running).
7. Deploy rules (from repo root):
   - `firebase deploy --only firestore:rules`
   - `firebase deploy --only storage:rules`
   - Init Firebase CLI first: `firebase login` + `firebase init` (select
     Firestore, Storage, Functions; keep files under `firebase/` if desired).

## Creating the first admin account (web panel)

1. Firebase Console → **Authentication → Users → Add user**
   → email + password (e.g. `admin@mepconnect.in`).
2. Firebase Console → **Firestore Database → Data** → add document:
   - Collection `users`, document id = the new user's **UID**
     (copy it from the Authentication → Users list),
   - fields: `role: "admin"`, `name: "…"`, `email: "…"`,
     `isBlocked: false`, `onboardingCompleted: true`,
     `createdAt`/`updatedAt` as timestamps.
3. Sign in at the admin panel URL with those credentials.

Client-side rules block self-service creation of `admin` roles, so this
console step is the only way to bootstrap admins.

## iOS phone-auth note

Phone OTP on iOS requires push notification capability (APNs):
1. In Xcode: **Runner target → Signing & Capabilities → + Push Notifications**
   (and enable the `aps-environment` entitlement).
2. Upload your APNs key/certificate to Firebase Console
   (**Project settings → Cloud Messaging → iOS app configuration**).
Without this, iOS still runs email login but phone OTP will fail.

## Google Maps (live tracking + navigation)

The customer app embeds a Google Map to track the technician, and the
technician app deep-links into the platform maps app for navigation.

1. Google Cloud Console → enable the **Maps SDK for Android** and the
   **Maps SDK for iOS** for your project.
2. Create an **API key** (restrict it to Android/iOS apps if desired).
3. Android: replace `PASTE_GOOGLE_MAPS_API_KEY` in
   `apps/mobile/android/app/src/main/AndroidManifest.xml`.
4. iOS: replace `PASTE_GOOGLE_MAPS_API_KEY` in
   `apps/mobile/ios/Runner/AppDelegate.swift`.

Without a key the app still runs; the embedded map shows a blank grid and
navigation deep links still open the platform maps app.

## In-app chat & masked calls

- Chats live under `chats/{bookingId}/messages` and are created automatically
  when a technician accepts a job (no setup needed).
- The "Call" button uses the `getContact` callable, which verifies the caller
  is part of the job before returning the other party's number — numbers are
  never stored in client-readable documents.
- True number masking (Twilio proxy/relay) is a later enhancement; today the
  call dials the verified number directly from the device.

## Ratings & reviews

- Reviews live at `reviews/{bookingId}` (one per booking), written by the
  customer after a job is completed. No setup needed — the technician's
  aggregate `rating`/`ratingsCount` is maintained automatically by the
  `onReviewWritten` Cloud Function.
- The technician profile queries `reviews` ordered by `createdAt`; the
  composite index is declared in `firebase/firestore.indexes.json` and is
  created automatically by `firebase deploy --only firestore:indexes`.

## Payments & earnings

- Payment records (`payments/{bookingId}`) are created and settled by the
  `initiatePayment` / `confirmPayment` callables — no client-side writes.
- **Cash** works out of the box: the customer marks the job paid and the
  technician's earnings update automatically.
- **UPI** opens the platform's UPI intent (`upi://pay`). Replace the
  placeholder VPA: pass `--dart-define=MEP_CONNECT_UPI_ID=merchant@upi`
  when running/building the app. Without it the UPI option shows a
  message and cash still works.
- A real gateway (Razorpay) with server-side order creation and webhook
  verification is the documented upgrade path; until then the callable
  is the source of truth for settlement.
- Technician earnings live on `technicians/{uid}` (`totalEarned`,
  `balance`, `earningsByMonth`) and the Earnings tab lists settled
  payments (composite index in `firestore.indexes.json`).

## Complaints & refunds

- Customers file complaints on completed jobs via the `submitComplaint`
  callable. Reason `job_not_done_properly` on a paid job auto-refunds
  (booking → `refunded`, payment → `refunded`, technician earnings
  reversed). Other reasons are queued for admin review (admin panel
  feature).
- Complaint photos go to `complaints/{bookingId}/photos` and are gated
  to the customer of a completed booking.

## Admin panel (web)

- Run `apps/admin_web` and sign in with an admin account (see "Creating
  the first admin account" above).
- Sections: Analytics (counts/revenue/top technicians), Jobs (all
  bookings + detail), Users (technician KYC approve/reject, customer
  password-reset email), Payments (settlements + process payouts
  against technician balance), Services (add/edit/deactivate
  categories — written directly via admin rules), Complaints (resolve
  with a note or issue a refund).
- Admin actions are gated server-side by `users/{uid}.role == 'admin'`
  in the `approveTechnicianKyc`, `resolveComplaint` and `processPayout`
  Cloud Functions.

## Cloud Functions (matching engine)

The matching engine (auto-match, accept/reject, retry scheduler, FCM push)
lives in `firebase/functions` (TypeScript, firebase-functions v2).

```bash
cd firebase/functions
npm install
cd ..  # back to firebase/
firebase deploy --only functions,firestore:rules,storage:rules
```

Requirements:
- The project must have **Cloud Functions** enabled (pay-as-you-go billing).
- The retry scheduler uses Cloud Scheduler (auto-provisioned on deploy).
- FCM push needs `users/{uid}.fcmToken` — the app writes it after login
  and permission is granted.

Without the functions deployed, bookings stay in `pending` and the
technician app cannot accept jobs (callables fail with a clear error).

## Per-developer

- Never commit real `google-services.json`, `GoogleService-Info.plist`, or a
  configured `firebase_options.dart` with production keys. Add them to
  `.gitignore` (see repo root `.gitignore`).
- If you are a code reviewer: the app shows a friendly
  “Firebase not configured” screen until step 6 is done.
