#!/usr/bin/env python3
"""Convert an llvm-cov LCOV report into SonarQube generic coverage XML."""

from __future__ import annotations

import pathlib
import sys
from fnmatch import fnmatch
import xml.etree.ElementTree as element_tree


def parse_lcov(path: pathlib.Path) -> dict[str, dict[int, int]]:
  coverage: dict[str, dict[int, int]] = {}
  source: str | None = None
  for line in path.read_text(encoding="utf-8").splitlines():
    if line.startswith("SF:"):
      source = line[3:]
      coverage.setdefault(source, {})
    elif line.startswith("DA:") and source is not None:
      line_number, hits = line[3:].split(",", maxsplit=1)
      coverage[source][int(line_number)] = int(hits)
  return coverage


def main() -> int:
  arguments = sys.argv[1:]
  if len(arguments) < 2:
    print("usage: lcov-to-sonarqube-generic.py <coverage.lcov> <coverage.xml> [--exclude <glob>]", file=sys.stderr)
    return 2
  input_path = pathlib.Path(arguments.pop(0))
  output_path = pathlib.Path(arguments.pop(0))
  exclusions: list[str] = []
  while arguments:
    option = arguments.pop(0)
    if option != "--exclude" or not arguments:
      print(f"unknown or incomplete option: {option}", file=sys.stderr)
      return 2
    exclusions.append(arguments.pop(0))
  root = element_tree.Element("coverage", version="1")
  for source, lines in sorted(parse_lcov(input_path).items()):
    if any(fnmatch(source, pattern) for pattern in exclusions):
      continue
    source_path = pathlib.Path(source).resolve()
    try:
      report_path = source_path.relative_to(pathlib.Path.cwd())
    except ValueError:
      report_path = source_path
    file_element = element_tree.SubElement(root, "file", path=str(report_path))
    for line_number, hits in sorted(lines.items()):
      element_tree.SubElement(file_element, "lineToCover", lineNumber=str(line_number), covered=str(hits > 0).lower())
  element_tree.ElementTree(root).write(output_path, encoding="utf-8", xml_declaration=True)
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
