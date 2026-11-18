# FreeTube 16 — compatibility edition

This is a separate **iOS 16.0+ WebKit compatibility app**, not a full port of
FreeTube's iOS 17-only native source. It lives in the existing `ios16-build`
branch so the native app can continue building unchanged.

## What works (website-dependent)

- YouTube mobile website browsing and playback in a persistent WKWebView
- Search and URL opening, back/forward/reload navigation
- Local saved-page bookmarks and sharing
- Website cookies, session and history (subject to YouTube restrictions)

## Not ported

- Native YouTubeKit/AVPlayer playback pipeline and mini player
- yt-dlp/FFmpeg downloads or offline playback, transcode or Files integration
- SwiftData history, favorites, playlists, subscription management
- Guaranteed sign-in, background audio or picture-in-picture

Google may reject authentication inside embedded WebKit browsers. Web playback
and functionality depend on YouTube's mobile site and are not verified on real
iOS 16 devices. These limitations are intentional and not hidden by the build.

## Building

The independent XcodeGen spec is `iOS16/project.yml`. On macOS with Xcode
and XcodeGen installed:

```sh
cd iOS16
xcodegen generate
xcodebuild -project FreeTubeIOS16.xcodeproj -scheme FreeTube16 \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

See **Actions > FreeTube 16 compatibility IPA** for the iOS 16 build artifact.
It is an **unsigned IPA** and must be signed using a valid signing identity
before installation. The existing `FreeTube` Xcode scheme still targets
iOS 17.0+ and is built by the separate baseline workflow.
