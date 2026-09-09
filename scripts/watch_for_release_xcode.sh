#!/bin/zsh
# Emit one line the moment a NON-BETA Xcode 27 appears on Xcode Cloud, then exit.
#
# A beta version string ends in a lowercase letter (27A5252f). The release does not (27A266a).
# That is the same test scripts/xcode_cloud_toolchain.rb and the 5.2 routine use, so this cannot
# disagree with them about what counts as shippable.
#
# Silence means "not yet". Any API failure is reported rather than swallowed, so a broken
# credential does not look identical to a quiet wait.
cd "$(dirname "$0")/.."
while true; do
  out=$(ruby scripts/xcode_cloud_toolchain.rb 2>&1) || {
    echo "CHECK FAILED: $(echo "$out" | tail -2 | tr '\n' ' ')"
    sleep 900; continue
  }
  hit=$(echo "$out" | grep -E "^  Xcode 27 " | grep -vi beta | head -1)
  if [ -n "$hit" ]; then
    echo "RELEASE XCODE 27 IS ON XCODE CLOUD: $(echo $hit)"
    echo "Next: ruby scripts/xcode_cloud_toolchain.rb --set 'Xcode 27', then push to main."
    exit 0
  fi
  sleep 900
done
