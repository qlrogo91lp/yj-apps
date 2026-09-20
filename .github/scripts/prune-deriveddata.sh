#!/usr/bin/env bash
#
# 가리키는 워크스페이스가 사라진 DerivedData("고아")를 찾아 지운다.
#
# DerivedData 폴더 이름 뒤의 해시는 워크스페이스의 **전체 경로**에서 나온다.
# 그래서 워크트리를 지우거나 프로젝트를 옮기면 그 폴더는 다시 읽히는 일 없이
# 수백 MB 를 차지한 채 남는다. 워크트리를 제거할 때 같이 돌린다.
# (CLAUDE.md > Git Workflow > 워크트리)
#
# 판정은 하나만 본다 — info.plist 의 WorkspacePath 가 실제로 존재하는가.
#   - 접두사(YJApps-*)로 거르지 않는다. YJKit-* 처럼 다른 이름으로 생기는 것을 놓친다
#   - WorkspacePath 는 .xcworkspace 일 수도, 평범한 디렉터리(SPM 패키지)일 수도 있어
#     접미사를 잘라내지 않고 경로 자체의 존재 여부를 본다
#   - 애매하면 "고아 아님" 쪽으로 떨어진다. 안 지우는 쪽이 안전하다
#   - info.plist 가 없는 항목(ModuleCache.noindex 등 Xcode 전역 캐시)은 판정 대상이 아니다
#
# 잘못 지워도 잃는 것은 빌드 산출물뿐이다. 비용은 풀 빌드 1회.
#
# 사용법: prune-deriveddata.sh [--apply]
#   --apply 를 주지 않으면 목록만 출력한다 (dry-run)
set -euo pipefail

root="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"

apply=false
case "${1-}" in
  --apply) apply=true ;;
  "") ;;
  *) echo "알 수 없는 인자: $1 (사용법: $(basename "$0") [--apply])" >&2; exit 2 ;;
esac

if [ ! -d "$root" ]; then
  echo "DerivedData 디렉터리가 없다: $root" >&2
  exit 1
fi

orphans=()
for dir in "$root"/*/; do
  dir="${dir%/}"
  plist="$dir/info.plist"
  [ -f "$plist" ] || continue

  workspace=$(plutil -extract WorkspacePath raw "$plist" 2>/dev/null) || continue
  [ -n "$workspace" ] || continue
  [ -e "$workspace" ] && continue

  orphans+=("$dir")
done

if [ ${#orphans[@]} -eq 0 ]; then
  echo "고아 DerivedData 없음 ($root)"
  exit 0
fi

total_kb=0
for dir in "${orphans[@]}"; do
  total_kb=$((total_kb + $(du -sk "$dir" | cut -f1)))
  accessed=$(plutil -extract LastAccessedDate raw "$dir/info.plist" 2>/dev/null || echo "-")
  printf '%-38s %6s  %-10s → %s\n' \
    "$(basename "$dir")" \
    "$(du -sh "$dir" | cut -f1)" \
    "${accessed:0:10}" \
    "$(plutil -extract WorkspacePath raw "$dir/info.plist")"
done
printf -- '--- 고아 %d개, 합계 %dMB ---\n' "${#orphans[@]}" "$((total_kb / 1024))"

if ! $apply; then
  echo "지우려면 make dd-prune-apply"
  exit 0
fi

for dir in "${orphans[@]}"; do
  # rm -rf 앞의 마지막 방어선 — DerivedData 루트 바로 아래가 아니면 건드리지 않는다
  case "$dir" in
    "$root"/*/*) echo "건너뜀 (루트 바로 아래가 아니다): $dir" >&2; continue ;;
    "$root"/?*) ;;
    *) echo "건너뜀 (DerivedData 밖이다): $dir" >&2; continue ;;
  esac
  rm -rf "$dir"
  echo "삭제: $(basename "$dir")"
done
