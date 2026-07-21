#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/apps/mobile"

cd "$MOBILE_DIR"
if [[ ! -d android || ! -d ios ]]; then
  flutter create \
    --org it.arteinferrolascari \
    --project-name arte_in_ferro_rapportini \
    --platforms android,ios \
    .
fi

# flutter create aggiunge un test dimostrativo riferito a MyApp. Il progetto
# usa ArteInFerroApp e mantiene i propri test, quindi rimuoviamo solo il demo.
rm -f test/widget_test.dart

python3 "$ROOT_DIR/tools/configure_mobile_platforms.py" "$MOBILE_DIR"
flutter pub get
