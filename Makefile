SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help build run test coverage coverage-check threads address leaks readme-media sonar ci
help:
	@printf '%s\n' 'build run test coverage-check threads address leaks readme-media sonar ci'
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
sonar:
	./script/sonar.sh
ci: coverage-check threads address leaks
