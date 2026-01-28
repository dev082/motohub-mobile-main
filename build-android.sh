#!/bin/bash
set -euo pipefail

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD_NUMBER=$(grep '^version:' pubspec.yaml | sed 's/.*+//')

flutter clean && flutter pub get
flutter build apk --release --split-per-abi

mkdir -p releases

[ -f "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ] && cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "releases/hubfrete-v${VERSION}-build${BUILD_NUMBER}-arm64-v8a.apk"
