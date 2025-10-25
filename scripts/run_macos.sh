#!/usr/bin/env bash
set -euo pipefail

# Run Flutter project for macOS from repository root.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$repo_root/app"

if [[ ! -f "$project_dir/pubspec.yaml" ]]; then
  echo "pubspec.yaml not found at $project_dir" >&2
  exit 1
fi

cd "$project_dir"

if ! flutter config --machine >/dev/null 2>&1; then
  echo "Flutter SDK not found in PATH. Please install Flutter first." >&2
  exit 2
fi

flutter config --enable-macos-desktop
flutter run -d macos "$@"
