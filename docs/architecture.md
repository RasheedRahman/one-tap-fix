# MEP Connect — Architecture Blueprint

Single source of truth: `implementation_plan.docx` (project root).
This file records the technical architecture and every decision made during development.
It must stay in sync with every feature implemented.

## 1. Stack

- Flutter (mobile: Customer + Technician modules, role-gated in one app)
- Flutter Web (Admin Panel, separate app)
- Firebase Authentication (Phone OTP primary, Email/Password fallback)
- Cloud Firestore (single shared database)
- Firebase Storage (media, KYC, certifications)
- Firebase Cloud Messaging (notifications — wired when booking features land)
- Cloud Functions (only when required: auto-matching, payouts, FCM orchestration)
- State management: Provider
- UI: Material 3
- Payments: Razorpay (UPI / cards / wallets / netbanking), Cash fallback

## 2. Repo Layout

```
one_tap_fix/
├── implementation_plan.docx     # Product source of truth
├── docs/architecture.md         # This file
├── firebase/                    # Rules + indexes + setup guide
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   ├── storage.rules
│   └── setup_guide.md
└── apps/
    ├── mobile/                  # Customer + Technician (role-gated)
    │   └── package: com.onetapfix.mepconnect
    └── admin_web/               # Admin panel (Flutter Web)
        └── package: com.onetapfix.mep_connect_admin
```

## 3. Firestore Schema (target, implemented incrementally)

```
users/{uid}
  role: "customer" | "technician" | "admin"
  name, phone, email?, photoUrl?, locale, languages[],
  isBlocked, isOnline, fcmToken?, onboardingCompleted,
  createdAt, updatedAt

technicians/{uid}                 # technician-only profile
  skills[], experienceYears, idVerification{status,docs},
  certifications[], rating, ratingsCount, completedJobs,
  cancelledJobs, isAvailable, currentLocation(GeoPoint),
  totalEarned, balance, earningsByMonth{"YYYY-MM": n},
  subscription{plan,status,expiry}, kyc{status,remarks}

services/{id}                     # admin-managed categories
  name, nameLocalized{ta,kn,hi,en}, icon, minCharge,
  serviceCharge, sparePartsPriceList, gstPercent,
  isActive, sortOrder, tags[] (emergency)

bookings/{id}                     # core entity
  bookingId(short), customerId, technicianId?, categoryId,
  description, mediaUrls[], scheduledAt,
  status: pending|matching|accepted|en_route|in_progress|
          completed|cancelled|refunded,
  location{lat,lng,address,GeoPoint}, isEmergency,
  matching{candidates[],matchScore,matchedAt}, etaMinutes,
  pricing{minCharge,serviceCharge,spareParts,gst,discount,total},
  payment{method,status,transactionId,paidAt},
  complaint{reason,status,resolution,refundId},
  rating{stars,comment,photoUrls[]}, timestamps

bookings/{id}/messages/{msgId}    # chat: from,to,type(text|image),
                                  # content, mediaUrl, sentAt, readAt

chats/{bookingId}                 # chat summary: customerId,
                                  # technicianId, lastMessage,
                                  # lastMessageAt, createdAt
chats/{bookingId}/messages/{msgId}   # senderId, type(text|image),
                                     # text?, mediaUrl?, createdAt

reviews/{bookingId}               # one per booking: customerId,
                                  # technicianId, rating(1-5),
                                  # reviewText, photos[], createdAt
                                  # technician aggregate on
                                  # technicians/{uid}.rating(Sum|Count)

payments/{id}                     # type(payment|payout|subscription),
                                  # bookingId?, technicianId?, amount,
                                  # gateway, status, method, createdAt
payments/{bookingId}              # one per booking: customerId,
                                  # technicianId, method(upi|cash),
                                  # amount, status(initiated|succeeded|
                                  # refunded), transactionId, paidAt

complaints/{bookingId}            # one per booking: customerId,
                                  # technicianId, reason, description,
                                  # photoUrls[], status, createdAt

subscriptions/{techId}            # plan(monthly|yearly), amount,
                                  # status, startedAt, expiresAt

offers/{id}                       # promotions on home screen

spare_parts/{id}, spare_orders/{id}
technician_tracking/{techId}      # live GeoPoint while online
```

## 4. Storage Layout

```
users/{uid}/profile.jpg
bookings/{bookingId}/problem_photos/{file}
bookings/{bookingId}/problem_videos/{file}
technicians/{uid}/kyc/{file}
technicians/{uid}/certifications/{file}
chats/{chatId}/photos/{file}
reviews/{bookingId}/photos/{file}
complaints/{complaintId}/photos/{file}
offers/{offerId}/banner.jpg
```

## 5. Navigation

- Mobile: Splash → Auth (Phone OTP or Email) → Role Gate → CustomerShell
  (Home / Bookings / Profile) or TechnicianShell (Dashboard / Jobs / Earnings / Profile).
  Admin role on mobile is blocked (admin lives on web).
- Admin Web: Login (email) → role check `users/{uid}.role == "admin"` →
  AdminShell (Dashboard / Jobs / Users / Payments / Services / Complaints).
- Router: plain `Navigator` + `AuthGate` widget pattern (no go_router).
  Chosen for explicit role-branching control; deep links not required by plan.

## 6. Decision Log

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Monorepo, two Flutter apps | Clean separation of mobile vs admin; separate deploys |
| 2 | Phone OTP primary, Email fallback | Indian market (ta/kn/hi/en); admin web uses email |
| 3 | Package id com.onetapfix.mepconnect | Chosen by product owner |
| 4 | Razorpay | Dominant Indian gateway; UPI/cards/wallets/netbanking; web SDK for admin |
| 5 | Provider (not Riverpod/Bloc) | Fixed in plan; minimal ceremony |
| 6 | Single `users/{uid}` doc + `technicians/{uid}` | Role-agnostic auth reads; technician data stays separate |
| 7 | Navigator + AuthGate, not go_router | Explicit role branching; no deep links needed |
| 8 | Dependencies added per-feature | Keeps builds lean, avoids unused-plugin bloat |
| 9 | Mobile blocks admin role | Admin panel is web-only per plan |
| 10 | Role immutable after onboarding | Rules forbid role/isBlocked changes from clients |
| 11 | Admin accounts bootstrapped in Firebase Console | Clients cannot self-create admin roles |
| 12 | Profile photo deferred to profile feature | Auth feature stays focused; storage rule already scoped |
| 13 | Catalog seeded via console JSON; `iconKey` → local IconData map | Admin services UI ships later; no binary icon assets |
| 14 | Media upload: create doc → upload → update `mediaUrls` | Storage rules verify booking ownership; rollback on failure |
| 15 | Pricing snapshot written to booking at creation | Transparent + immutable per plan's transparent pricing |
| 16 | Emergency booking = `isEmergency` flag + `scheduledAt: now` | Dispatch/matching lands with the matching feature |
| 17 | Bookings tab shows live list + cancel pending | Minimal useful surface until service-history feature |
| 18 | Matching runs in Cloud Functions (onCreate + callables + scheduler) | Race-free assignment, timeouts, FCM — server-side concerns |
| 19 | Scoring = 40% rating + 60% distance, top-5 within 25 km (15 km emergency) | Plan §5 smart auto-matching (skill/rating/distance/availability) |
| 20 | Accept = transactional callable; first technician wins | Prevents double assignment |
| 21 | Technician onboarding writes skills+experience; immutable via rules | Feeds the matching engine; admin edits later |
| 22 | Availability toggle writes live location every 60 s | Distance scoring needs fresh technician coordinates |
| 23 | Retry scheduler: timeout 30 min (10 min emergency), 2 attempts → cancelled | Plan's "within 10 minutes" emergency promise |
| 24 | FCM: token on users.fcmToken; AppEvents bus for tab navigation | Cross-shell navigation without deep-link complexity |
| 25 | On-site flow = callables (`updateJobStatus`, `cancelJob`) | State machine + technician stats + FCM stay server-side; rules stay simple |
| 26 | Location timer speeds to 15 s while technician holds an active job | Customer's live map tracks the technician closely (plan §2.3) |
| 27 | Customer tracking = embedded Google Map + `technicians/{uid}` stream | Real-time marker without a dedicated location collection |
| 28 | Navigation = deep link to platform maps (`url_launcher`) | Plan §3.4 "open maps from job page"; no SDK billing per launch |
| 29 | Customer cancel of assigned jobs goes through `cancelJob` callable | Must update technician pool/notify; client rules only cover pending/matching |
| 30 | Technician-cancelled jobs increment `technicians.cancelledJobs` | Feeds reliability stats used by future rating/visibility logic |
| 31 | Chat = `chats/{bookingId}` + `messages/{msgId}` subcollection | Chat per job (plan §2.4); booking id doubles as chat id |
| 32 | Chat doc created in `acceptJob` transaction | No chat until a technician exists; no orphan docs |
| 33 | Messages written client-side; `createdAt == request.time` in rules | Immutable chat log; client cannot backdate; update/delete denied |
| 34 | Photos → `chats/{bookingId}/photos`, message type `image` | Reuses storage + URL pattern from booking media |
| 35 | Masked contact = `getContact` callable (participant-only, returns other party's name/phone) | Numbers never client-readable; true Twilio-style relay is future work |
| 36 | Global `appNavigatorKey` on MaterialApp | FCM chat taps deep-link into ChatScreen without a router |
| 37 | `onChatMessageCreated` trigger → FCM + chat summary (`lastMessage`/`lastMessageAt`) | Push without per-message client callables |
| 38 | Review doc id = booking id (one review per booking) | `!exists(...)` in rules enforces uniqueness; natural join key |
| 39 | Technician rating aggregate maintained by `onReviewWritten` trigger | Clients never touch stats (rules freeze rating/ratingsCount) |
| 40 | Review photos → `reviews/{bookingId}/photos`, upload before doc create | Storage rule checks completed booking + owner; doc references URLs |
| 41 | `ratingSum`/`ratingsCount` stored alongside `rating` on technician | Incremental updates survive partial failures; UI needs the count |
| 42 | Review `createdAt == request.time`; rating immutable via rules | Customers cannot backdate or edit a submitted rating |
| 43 | Invoice = read-only presentation of the booking's pricing snapshot; number `INV-{shortId}` | Stable, derivable client-side; no server docs or PDF pipeline |
| 44 | Service history = bookings query filtered by `status` segment | Reuses the bookings read rules; no new collection |
| 45 | History segmented Completed / Cancelled / Refunded | Plan §5 "old service records"; cancellations are factual history |
| 46 | Payments = `payments/{bookingId}` + booking `payment` map; server-owned | Clients never touch money state; rules freeze the payment map |
| 47 | `initiatePayment`/`confirmPayment` callables; amount recomputed from pricing snapshot | Client-supplied totals are never trusted |
| 48 | Cash + UPI: UPI opens `upi://pay` with `PASTE_MERCHANT_UPI_ID` placeholder; confirm after intent | Razorpay/webhook verification is the gateway upgrade path; app works offline today |
| 49 | Earnings = technician doc aggregates (`totalEarned`, `balance`, `earningsByMonth`) + payments query | Incremental server-side sums; no per-payment client math |
| 50 | Withdraw button disabled until admin payouts | Plan §4.4 payout management is admin-side work |
| 51 | Complaints = `complaints/{bookingId}` via `submitComplaint` callable | One per booking; server verifies completed status + ownership |
| 52 | Auto-refund only for `job_not_done_properly` on paid jobs | Plan §2.8 "auto-refund if job not done properly"; other reasons go to admin review |
| 53 | Refund reverses payment status + booking status + technician earnings in one transaction | Ledger stays consistent; gateway reversal is future work |
| 54 | Admin callables (`approveTechnicianKyc`, `resolveComplaint`, `processPayout`) all require role==admin server-side | Rules freeze technician stats for self-updates; admin web writes services/offers directly (rules allow) |
| 55 | Payouts are `payments/{id}` docs with `type: 'payout'`; booking payments carry `type: 'payment'` | One collection for the whole ledger; mobile earnings filter excludes payouts |
| 56 | Admin web = six sections (Analytics, Jobs, Users, Payments, Services, Complaints) on the existing shell | Plan §4; services CRUD writes Firestore directly via admin rules |
| 57 | Analytics = bounded Firestore queries (counts, month revenue, top-rated) | Dashboard approximations; precise aggregates deferred to daily reports |
| 58 | Payments/payouts/analytics queries declared as composite indexes in `firestore.indexes.json` | Firestore refuses compound queries without them; deploy creates them |

## 7. Security Rules Philosophy

- Least privilege: users can read/write only their own `users/{uid}` doc.
- Admin actions restricted via `users/$(request.auth.uid).role == 'admin'`.
- Booking/chat/payment rules are added when those features land.
- Storage mirrors Firestore: user-scoped paths only.
