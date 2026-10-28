#!/usr/bin/env bash
# Reproduce the tested cloud prerequisites without sudo or tracked-file changes.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tools_root=/workspace/toolchains
mkdir -p "$tools_root"
python3 - "$tools_root" <<'PY'
import sys,pathlib,urllib.request,hashlib,zipfile,tarfile
r=pathlib.Path(sys.argv[1])
artifacts=[
 ('jdk.tar.gz','https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_x64_linux_hotspot_21.0.9_10.tar.gz','810d3773df7e0d6c4394e4e244b264c8b30e0b05a0acf542d065fd78a6b65c2f',r/'jdk-21.0.9+10/bin/javac'),
 ('android-tools.zip','https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip','2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258',r/'android-sdk/cmdline-tools/latest/bin/sdkmanager')]
for name,url,digest,installed in artifacts:
 if installed.exists():continue
 archive=r/name
 if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest()!=digest:
  with urllib.request.urlopen(url,timeout=120) as response,archive.open('wb') as output:
   while chunk:=response.read(1024*1024):output.write(chunk)
 if hashlib.sha256(archive.read_bytes()).hexdigest()!=digest:raise RuntimeError('Checksum mismatch: '+name)
 if name.endswith('.gz'):
  with tarfile.open(archive) as t:t.extractall(r,filter='data')
 else:
  tmp=r/'android-extract';tmp.mkdir(exist_ok=True)
  with zipfile.ZipFile(archive) as z:z.extractall(tmp)
  installed.parent.parent.parent.mkdir(parents=True,exist_ok=True)
  (tmp/'cmdline-tools').rename(installed.parent.parent)
  for f in installed.parent.iterdir():f.chmod(0o755)
print('JDK and Android CLI available; downloaded archives verified using pinned SHA-256.')
PY
export JAVA_HOME="$tools_root/jdk-21.0.9+10"
export ANDROID_HOME="$tools_root/android-sdk"
java_flags=()
if [[ -n "${HTTPS_PROXY:-}" ]]; then
 read -r proxy_host proxy_port < <(python3 - <<'PY'
import os,urllib.parse
u=urllib.parse.urlparse(os.environ['HTTPS_PROXY']);print(u.hostname,u.port or 80)
PY
 )
 java_flags+=("-Dhttps.proxyHost=$proxy_host" "-Dhttps.proxyPort=$proxy_port" "-Dhttp.proxyHost=$proxy_host" "-Dhttp.proxyPort=$proxy_port")
fi
if [[ -f /etc/codex/network-policy.json && -f /etc/ssl/certs/java/cacerts ]]; then java_flags+=("-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts"); fi
# Preserve any injected JVM options. SDK licenses are required by Android development.
export JAVA_OPTS="${JAVA_OPTS:-} ${java_flags[*]}"
set +o pipefail
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses > "$tools_root/licenses.log" 2>&1
sdk_license_status=${PIPESTATUS[1]}
set -o pipefail
[[ "$sdk_license_status" -eq 0 ]]
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" 'platforms;android-35' 'build-tools;35.0.0' 'platform-tools'
cd "$repo_root"
npm ci --ignore-scripts
