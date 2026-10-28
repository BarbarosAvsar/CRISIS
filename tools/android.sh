#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x /workspace/toolchains/jdk-21.0.9+10/bin/javac && -z "${JAVA_HOME:-}" ]]; then
 export JAVA_HOME=/workspace/toolchains/jdk-21.0.9+10
fi
if [[ -d /workspace/toolchains/android-sdk && -z "${ANDROID_HOME:-}" ]]; then
 export ANDROID_HOME=/workspace/toolchains/android-sdk
fi
proxy_args=()
# Java does not automatically honor the session HTTP(S)_PROXY variables.
# Parse only public proxy host/port; never echo credentials or modify proxy routing.
if [[ -n "${HTTPS_PROXY:-}" ]]; then
 read -r proxy_host proxy_port < <(python3 - <<'PY'
import os, urllib.parse
u=urllib.parse.urlparse(os.environ['HTTPS_PROXY'])
if u.hostname: print(u.hostname,u.port or 80)
PY
 )
 if [[ -n "${proxy_host:-}" ]]; then
  proxy_args+=("-Dhttps.proxyHost=$proxy_host" "-Dhttps.proxyPort=$proxy_port" "-Dhttp.proxyHost=$proxy_host" "-Dhttp.proxyPort=$proxy_port")
 fi
fi
# Reuse the managed machine's Java trust store, including the session CA.
if [[ -f /etc/codex/network-policy.json && -f /etc/ssl/certs/java/cacerts ]]; then
 proxy_args+=("-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts")
fi
cd "$repo_root/android"
exec ./gradlew --no-daemon "${proxy_args[@]}" "$@"
