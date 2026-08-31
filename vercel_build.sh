#!/usr/bin/env bash
# Builds the Flutter web bundle inside the Vercel build container.
# Vercel's build image has no Flutter SDK, so we fetch a pinned stable
# release, then run a normal `flutter build web`.

set -euo pipefail

# Keep this in sync with the SDK the app is developed against.
FLUTTER_VERSION="3.38.7"
FLUTTER_HOME="$HOME/flutter"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Cloning Flutter $FLUTTER_VERSION ..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
else
  echo "Reusing cached Flutter SDK at $FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

# Avoid "dubious ownership" git errors on the cloned SDK in CI.
git config --global --add safe.directory "$FLUTTER_HOME" || true

flutter --version
flutter config --enable-web --no-analytics
flutter pub get

# --base-href "/" is correct for a root-domain Vercel deployment.
flutter build web --release --base-href "/"

echo "Flutter web build complete -> build/web"
