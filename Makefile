SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help build run test coverage coverage-check threads address leaks readme-media ships ships-check showroom-data showroom-import showroom-check mission-packs-check script-missions-check liberator-design hull-designs package-macos sonar ci
help:
	@printf '%s\n' 'build run test coverage-check threads address leaks readme-media ships ships-check showroom-data showroom-import showroom-check mission-packs-check script-missions-check liberator-design hull-designs package-macos sonar ci'
build:
	swift build
run:
	./script/build_and_run.sh
test:
	swift test
coverage coverage-check:
	./script/coverage.sh
threads:
	swift test --scratch-path .build/tsan --sanitize=thread
address:
	ASAN_OPTIONS=detect_leaks=0 swift test --scratch-path .build/asan --sanitize=address
leaks:
	swift build
	mkdir -p reports
	/usr/bin/leaks --atExit -- "$$(swift build --show-bin-path)/Elite" --diagnostics > reports/leaks.txt 2>&1
	@tail -8 reports/leaks.txt
readme-media:
	swift run Elite --readme-media
	mkdir -p Resources
	iconutil -c icns .build/Elite.iconset -o Resources/Elite.icns
ships showroom-data:
	python3 Tools/showroom/ship-reference.py
ships-check:
	python3 Tools/showroom/ship-reference.py --check
showroom-import:
	python3 Tools/showroom/build-catalogue.py --models "$(SHOWROOM_MODELS)" --expansions "$(SHOWROOM_EXPANSIONS)" $(if $(SHOWROOM_MODEL_CACHE),--model-cache "$(SHOWROOM_MODEL_CACHE)")
showroom-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/showroom -p 'test_*.py'
hull-designs:
	python3 Tools/showroom/refine-catalogue.py
liberator-design:
	python3 Tools/showroom/liberator-design.py
sonar:
	./script/sonar.sh
mission-packs-check:
	swift run Elite --validate-mission-pack docs/mission-packs/courier.toml
script-missions-check:
	swift run Elite --validate-mission-pack docs/mission-packs/scripted-courier
	swift run Elite --validate-mission-pack docs/mission-packs/scripted-patrol
	swift run Elite --validate-mission-pack docs/mission-packs/scripted-passengers
	swift run Elite --validate-mission-pack docs/mission-packs/scripted-equipment
package-macos:
	python3 Tools/distribution/package_macos.py
ci: ships-check showroom-check mission-packs-check script-missions-check coverage-check threads address leaks
