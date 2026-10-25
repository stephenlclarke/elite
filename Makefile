SHELL := /bin/bash
.DEFAULT_GOAL := help
RELEASE_PLAN ?= dist/release-plan.json
.PHONY: release-plan publish-release release-readme release
.PHONY: sanitizer-checkpoints-check native-runner-check instance-equality-check ci-capture-check help build run test unit-ci local-runner-check coverage coverage-check threads threads-full address leaks readme-media induction-ark-model induction-crew-log-model ships ships-check showroom-data showroom-import showroom-check liberator-design hull-designs mission-packs-check flight-controls-check package-macos homebrew-cask homebrew-cask-check sonar ci
help:
	@printf '%s\n' 'build run test unit-ci sanitizer-checkpoints-check instance-equality-check local-runner-check ci-capture-check coverage-check threads threads-full address leaks readme-media induction-ark-model induction-crew-log-model ships ships-check showroom-data showroom-import showroom-check liberator-design hull-designs mission-packs-check flight-controls-check release-plan package-macos publish-release release-readme release homebrew-cask homebrew-cask-check sonar ci'
build:
	swift build
run:
	./script/build_and_run.sh
test:
	swift test
unit-ci: instance-equality-check
	python3 Tools/CI/isolated_units.py
local-runner-check:
	python3 -m unittest discover -s Tools/CI -p 'test_local_runner.py'
coverage coverage-check: sanitizer-checkpoints-check
	python3 Tools/CI/quality_phase_checkpoints.py normal
sanitizer-checkpoints-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_sanitizer_checkpoints.py'
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_quality_phase_checkpoints.py'
threads: sanitizer-checkpoints-check
	python3 Tools/CI/sanitizer_checkpoints.py thread
address: sanitizer-checkpoints-check
	python3 Tools/CI/sanitizer_checkpoints.py address
threads-full: sanitizer-checkpoints-check
	python3 Tools/CI/sanitizer_checkpoints.py thread --full-concurrent
leaks: sanitizer-checkpoints-check
	python3 Tools/CI/quality_phase_checkpoints.py leaks
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
release-plan:
	python3 Tools/distribution/release_version.py --output "$(RELEASE_PLAN)"
package-macos:
	python3 Tools/distribution/package_macos.py --release-plan "$(RELEASE_PLAN)"
publish-release:
	python3 Tools/distribution/release_macos.py publish --release-plan "$(RELEASE_PLAN)"
release-readme:
	python3 Tools/distribution/release_macos.py readme --release-plan "$(RELEASE_PLAN)"
release: release-plan
	$(MAKE) package-macos
	$(MAKE) publish-release
homebrew-cask:
	python3 Tools/distribution/homebrew_cask.py --release-plan "$(RELEASE_PLAN)" $(if $(ELITE_HOMEBREW_TAP),--tap "$(ELITE_HOMEBREW_TAP)")
homebrew-cask-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/distribution -p 'test_*.py'
	python3 Tools/distribution/homebrew_cask.py --check
ci-capture-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_crash_artifacts.py'
native-runner-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_native_runner.py'

ci: native-runner-check instance-equality-check ci-capture-check flight-controls-check homebrew-cask-check ships-check showroom-check mission-packs-check coverage-check threads address leaks

instance-equality-check:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p 'test_script_instance_equality.py'
	python3 Tools/CI/script_instance_equality.py
