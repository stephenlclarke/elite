#!/usr/bin/env python3
"""Fail when SonarQube generic coverage falls below the configured floor."""

from __future__ import annotations

import argparse
import xml.etree.ElementTree as element_tree


def main() -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument("--minimum", type=float, required=True)
  parser.add_argument("--coverage", required=True)
  arguments = parser.parse_args()
  root = element_tree.parse(arguments.coverage).getroot()
  lines = root.findall(".//lineToCover")
  covered = sum(line.attrib.get("covered") == "true" for line in lines)
  percentage = 100 * covered / len(lines) if lines else 0
  print(f"Swift coverage: {percentage:.2f}%")
  return 0 if percentage >= arguments.minimum else 1


if __name__ == "__main__":
  raise SystemExit(main())
