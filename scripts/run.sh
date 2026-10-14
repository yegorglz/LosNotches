#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x LosNotches || true
scripts/build-app.sh debug
open build/LosNotches.app
