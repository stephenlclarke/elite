SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: ci-capture-check help build run test unit-ci coverage coverage-check threads address leaks readme-media induction-ark-model induction-crew-log-model ships ships-check showroom-data showroom-import showroom-check liberator-design hull-designs mission-packs-check flight-controls-check package-macos homebrew-cask homebrew-cask-check sonar ci
help:
	@printf '%s\n' 'build run test unit-ci ci-capture-check coverage-check threads address leaks readme-media induction-ark-model induction-crew-log-model ships ships-check showroom-data showroom-import showroom-check liberator-design hull-designs mission-packs-check flight-controls-check package-macos homebrew-cask homebrew-cask-check sonar ci'
build:
	swift build
run:
	./script/build_and_run.sh
test:
	swift test
unit-ci:
	python3 Tools/CI/isolated_units.py
coverage coverage-check:
	./script/coverage.sh
threads:
	swift test --scratch-path .build/tsan --sanitize=thread
address:
	ASAN_OPTIONS=detect_leaks=0 swift test --scratch-path .build/asan --sanitize=address --no-parallel
leaks:
	swift build
	mkdir -p reports
	/usr/bin/leaks --atExit -- "$$(swift build --show-bin-path)/Elite" --diagnostics > reports/leaks.txt 2>&1
	@tail -8 reports/leaks.txt
readme-media:
	swift run Elite --readme-media
	mkdir -p Resources
	iconutil -c icns .build/Elite.iconset -o Resources/Elite.icns

induction-ark-model:
	python3 Tools/export-induction-ark-model.py

induction-crew-log-model:
	python3 Tools/export-induction-ark-model.py --crew-log
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
flight-controls-check:
	PYTHONDONTWRITEBYTECODE=1 python3 Tools/generate-flight-controls.py --repo-root . --check
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_flight_controls.py'
package-macos:
	python3 Tools/distribution/package_macos.py
homebrew-cask:
	python3 Tools/distribution/homebrew_cask.py --version "$(ELITE_HOMEBREW_VERSION)" --asset-commit "$(ELITE_HOMEBREW_COMMIT)" $(if $(ELITE_HOMEBREW_TAP),--tap "$(ELITE_HOMEBREW_TAP)")
homebrew-cask-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/distribution -p 'test_*.py'
	python3 Tools/distribution/homebrew_cask.py --check
ci-capture-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_crash_artifacts.py'
ci: ci-capture-check flight-controls-check homebrew-cask-check ships-check showroom-check mission-packs-check coverage-check threads address leaks
