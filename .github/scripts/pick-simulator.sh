#!/usr/bin/env bash
#
# 사용 가능한 시뮬레이터 중 지정 플랫폼의 **최신 런타임**에서 기기 하나를 골라 UDID를 출력한다.
#
# 기기 이름을 -destination 에 직접 쓰지 않는 이유:
#   런타임이 둘 이상 설치되면 같은 이름의 기기가 중복되어 매칭이 실패한다.
#   실제로 iPhone 17 Pro 가 iOS 26.4·26.5 에, Apple Watch Series 11 (46mm) 이
#   watchOS 26.4·26.5 에 동시에 존재해 빌드가 깨진 적이 있다.
#   (docs/superpowers/specs/2026-08-27-ci-pipeline-design.md 5.1)
#
# 사용법: pick-simulator.sh <iOS|watchOS> <기기 이름 정규식>
set -euo pipefail

platform="${1:?platform 인자가 필요하다 (iOS | watchOS)}"
pattern="${2:?기기 이름 정규식 인자가 필요하다}"

# 런타임 키는 com.apple.CoreSimulator.SimRuntime.iOS-26-5 형태다.
# 문자열 정렬은 26-10 < 26-5 로 뒤집히므로 버전을 숫자 배열로 파싱해 정렬한다.
udid=$(xcrun simctl list devices available --json | jq -r \
  --arg platform "$platform" --arg pattern "$pattern" '
    .devices
    | to_entries
    | map(select(.key | test("SimRuntime\\." + $platform + "-[0-9]")))
    | map(.version = (.key | capture("-(?<a>[0-9]+)-(?<b>[0-9]+)$")
                           | [(.a | tonumber), (.b | tonumber)]))
    | sort_by(.version) | reverse
    | map(.value
          | map(select(.name | test($pattern)))
          # 기기 세대 숫자가 큰 것을 고른다. 괄호 안 크기(46mm)가 세대로
          # 오인되지 않도록 먼저 제거한다. 동률이면 이름 사전순으로 확정한다.
          | map(. + {gen: ((.name | gsub("\\([^)]*\\)"; "")
                                  | [scan("[0-9]+")] | map(tonumber) | max) // 0)})
          | sort_by([(-.gen), .name])
          | .[0].udid)
    | map(select(. != null))
    | .[0] // empty
  ')

if [ -z "$udid" ]; then
  echo "::error::${platform} 런타임에서 '${pattern}' 에 맞는 시뮬레이터를 찾지 못했다." >&2
  echo "--- 사용 가능한 기기 목록 ---" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

echo "$udid"
