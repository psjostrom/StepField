#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

SDK="/Users/persjo/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
DEVICE="fr970"

mkdir -p build

"$SDK/bin/monkeyc" \
    -e \
    -f monkey.jungle \
    -o "build/StepField.iq" \
    -d "$DEVICE" \
    -y "$KEY" \
    -w

echo "Built: build/StepField.iq"
