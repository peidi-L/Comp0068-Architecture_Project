#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLED_JAVA="$PROJECT_DIR/tools/java17/jdk-17.0.21+9-jre/Contents/Home/bin/java"

if [[ -x "$BUNDLED_JAVA" ]]; then
  JAVA_BIN="$BUNDLED_JAVA"
elif command -v java >/dev/null 2>&1; then
  JAVA_BIN="$(command -v java)"
else
  echo "Java 17 or later is required to run MARS." >&2
  echo "Install Java, then run this launcher again." >&2
  exit 1
fi

exec "$JAVA_BIN" -jar "$PROJECT_DIR/tools/Mars4_5.jar" "$@"
