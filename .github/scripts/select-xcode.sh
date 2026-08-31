#!/usr/bin/env bash
#
# 러너의 기본 Xcode 가 바뀌면 빌드 결과가 흔들리므로 버전을 고정한다.
# XCODE_VERSION 이 러너에 없으면 경고만 남기고 기본 버전으로 진행한다 —
# 러너 이미지가 갱신되는 시점에 CI 전체가 멈추는 것보다 낫다.
set -euo pipefail

version="${XCODE_VERSION:?XCODE_VERSION 환경변수가 필요하다}"

echo "--- 설치된 Xcode ---"
ls -d /Applications/Xcode*.app 2>/dev/null || true

target="/Applications/Xcode_${version}.app"
if [ -d "$target" ]; then
  sudo xcode-select -s "$target"
else
  echo "::warning::Xcode ${version} 이 러너에 없다 — 기본 버전을 쓴다"
fi

xcodebuild -version
