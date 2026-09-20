APPS := GolfCounter TennisCounter HaruchiFit
WORKSPACE := YJApps.xcworkspace

.PHONY: help lint format fix kit-test dd-prune dd-prune-apply

help:
	@echo "lint            앱별 swiftlint (검사만)"
	@echo "format          앱별 swiftformat --lint (검사만)"
	@echo "fix             앱별 swiftformat + swiftlint --fix (실제로 고침)"
	@echo "kit-test        Packages/YJKit 단독 테스트 (iOS 시뮬레이터)"
	@echo "dd-prune        고아 DerivedData 목록 (검사만)"
	@echo "dd-prune-apply  고아 DerivedData 삭제 (실제로 지움)"

lint:
	@for app in $(APPS); do \
		echo "==> $$app"; \
		( cd Apps/$$app && swiftlint ) || exit 1; \
	done

format:
	@for app in $(APPS); do \
		echo "==> $$app"; \
		( cd Apps/$$app && swiftformat --lint . ) || exit 1; \
	done

fix:
	@for app in $(APPS); do \
		echo "==> $$app"; \
		( cd Apps/$$app && swiftformat . && swiftlint --fix ) || exit 1; \
	done

# swift test 는 이 패키지에서 동작하지 않는다 (macOS 플랫폼 미선언).
# CI 는 시뮬레이터 이름이 런타임별로 중복되므로 UDID 를 넘긴다:
#   make kit-test KIT_DESTINATION="id=<UDID>"
KIT_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

kit-test:
	cd Packages/YJKit && xcodebuild -scheme YJKit-Package \
		-destination '$(KIT_DESTINATION)' test

# 워크트리를 지워도 그 DerivedData 는 남는다 — 폴더 이름이 워크스페이스 경로 해시라서
# 다시 읽히는 일 없이 수백 MB 를 차지한다. 워크트리를 제거할 때 같이 돌린다.
dd-prune:
	@.github/scripts/prune-deriveddata.sh

dd-prune-apply:
	@.github/scripts/prune-deriveddata.sh --apply
