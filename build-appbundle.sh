#!/bin/bash
set -euo pipefail

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD_NUMBER=$(grep '^version:' pubspec.yaml | sed 's/.*+//')

flutter clean && flutter pub get
flutter build appbundle --release

mkdir -p releases

[ -f "build/app/outputs/bundle/release/app-release.aab" ] && cp build/app/outputs/bundle/release/app-release.aab "releases/hubfrete-v${VERSION}-build${BUILD_NUMBER}.aab"
