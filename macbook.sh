#!/usr/bin/env bash
set -euo pipefail

if [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
/opt/homebrew/bin/brew install --cask --adopt visual-studio-code google-chrome studio-3t freelens
