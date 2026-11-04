# UX review and migration scope - 04/11/2026

Source: current Flutter screens, RN tabs/player/subscription/offline services,
and the existing backend controllers. Karaoke and advertising belong to a
collaborator's separate GitHub branch; do not implement those modules here.

## Findings and target flows

| Finding | Change and acceptance |
| --- | --- |
| Flutter's search-first home and large headings diverge from the RN app requested by the user | Restore the RN compact brand header, genre filters, two-column quick grid, artwork-backed spotlight, horizontal track shelf, circular artists, albums and track list. Omit empty albums; keep search/mood in the search tab |
| Search resets text/results inconsistently and has no recent searches | Controlled text field, clear action, explicit mood submit, account-scoped server history with replay/delete; never record keystrokes. Scroll header with the keyboard; retain LIMITED match status without claiming a strong match |
| Playlist creation is disconnected from adding a song | Create inside the picker; server-confirmed add; manage visibility/remove song/delete inside detail, with destructive confirmation |
| Library mixes every item in one long list | Dedicated views for playlists, liked tracks and saved albums; useful empty-state action |
| Player actions are buried in long expanded lists | Direct save/menu actions, queue and lyrics in focused sheets, sleep/volume controls; retain a single audio coordinator |
| Account is only a read-only identity page | Link to real subscription management, checkout and inbox; clarify refresh vs edit |
| RN downloads acknowledge success even if confirmation fails | Require server confirmation, encrypted user/device-scoped files, enforce expiry/revocation and clean decrypted files |
| Financial/native flows lack device/account evidence | Do not equate unit tests with real purchase, login or offline validation; track remaining acceptance separately |
| Checkout errors can leave an existing pending order | Require a successful management refresh before creating another order; pending receipts have an explicit status check and cancellation flow |

## Interaction rules

- Preserve Moodify purple, logo and Be Vietnam Pro; artwork supplies visual variety.
- Use functional controls and real metadata. No invented recommendations, badges,
  prices, payment success, lyrics or fallback media.
- Keep touch targets at least 48 logical pixels. Allow large text and scrollable
  sheets/dialogs. Show active playback, progress, retry and meaningful empty states.
- Protect mutations against double taps and session changes. Never auto-retry
  toggle/checkout operations. Keep protected data scoped to the active account.
- Bounded lists, lazy builders, small artwork decode sizes and independent loading
  states; no repository-wide indexing or generated placeholder architecture.

## RN layout and motion reference

Compared source: `src/app/(tabs)/index.tsx`, `_layout.tsx`, `explore.tsx`,
`library.tsx`, `profile.tsx`, `src/components/player/MiniPlayer.tsx` and
`FullscreenPlayer.tsx` in the old mobile checkout. This is source-based parity,
not a claim of pixel-perfect comparison against a running RN build.

| Area | Flutter implementation |
| --- | --- |
| Palette and density | RN background #0C0C10, surfaces #171720/#1F1F2E, purple #8B5CF6, lavender; compact header and 64 px tabs without Material selection pill |
| Home | Up to six playable named tracks in a two-column grid; stable first quick track in spotlight, real artwork blur; horizontal shelves and artist circles |
| Mini player | Floating rounded card, 44 px cover, title/artist, like, purple play circle, actual progress |
| Full player | Slide-up route, blurred cover background, rounded artwork, white play circle, thin seek/volume, real lyrics preview, queue/share/sleep; drag header down to close |
| Search/library/account | Filled two-mode search switch; list-based library with tabs; guest avatar card and compact account identity |
| Feedback | Press scale .975/120 ms, tab fade 180 ms, mini size 220 ms, section reveal 280 ms plus bounded stagger, cover/icon crossfades, sheet 280/220 ms and route 320/240 ms |

Reduced motion disables the custom transitions and skips AnimatedSize. Section
entrances run once per mounted section; player ticks do not restart them. Blur
is confined to decoded artwork at cacheWidth 360, with RepaintBoundary; LRC
parsing is memoized per track. No animation dependency or additional player engine.

Do not port the RN source's unverified trending/ranking labels or randomized
spotlight claims. Flutter labels the catalog as discovery/all songs and does not
fabricate history or personal recommendations. Keep missing artwork neutral.

Widget coverage includes the guest home → playback → full player → library →
search/mood flow, a 320×640 viewport at text scale 1.8, a 280 px keyboard inset,
and a reduced-motion scenario. Device evidence and remaining gates live in STATE.

## Scope still requiring separate acceptance

Social OAuth requires app/provider configuration. Protected flows require a user
to sign in on the device. Payment success requires an actual provider event;
offline expiry/revocation and iOS need their own native evidence. Karaoke/ad
integration is coordinated through the existing player/router on the other branch.
