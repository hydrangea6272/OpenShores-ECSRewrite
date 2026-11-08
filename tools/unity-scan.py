#!/usr/bin/env python3
"""List sources that can't safely share a unity batch.

Unity builds (AU_UNITY_BUILD=ON) compile several .cpp files of one target as a
single translation unit. That breaks when two files of the same target define
the same file-scope name (a static variable or function, a class, a typedef),
and it can silently change behaviour when they #define the same macro with
different values (between two .cpp files, or between a .cpp file and a
header, since a header's include guard stops it restoring its own value for
later files in the batch).

This scans each library and program directory for such names and prints the
files involved as a CMake list, ready to paste into AU_UNITY_EXCLUDE in
cmake/AuBuildSpeed.cmake.

    python3 tools/unity-scan.py           # CMake list
    python3 tools/unity-scan.py --why     # also show the clashing names

The scan is a line-based heuristic for column-0 declarations, so it can miss
unusual layouts. Anything it misses fails loudly at compile time in a unity
build; add those files by hand.
"""
import argparse
import collections
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_PARENTS = [
    "src/lib",
    "src/app/servers",
    "src/app/clients",
    "src/app/account",
    "src/app/admin",
    "src/tools",
]

DECLARATIONS = [
    # static variables and functions, optionally templated
    re.compile(r"^(?:template\s*<[^>]*>\s*)?static\s+(?:const\s+|inline\s+|constexpr\s+)*"
               r"[\w:<>,\s\*&]+?[\s\*&](\w+)\s*(?:\[|=|;|\()"),
    # class, struct, union and enum definitions
    re.compile(r"^(?:class|struct|union|enum(?:\s+class)?)\s+(\w+)\s*(?::[^;{]*)?\{?\s*(?://.*)?$"),
    re.compile(r"^typedef\s+.*?(\w+)\s*;"),
]
DEFINE = re.compile(r"^\s*#\s*define\s+(\w+)(.*)")


def target_directories():
    for parent in TARGET_PARENTS:
        path = os.path.join(ROOT, parent)
        if not os.path.isdir(path):
            continue
        for name in sorted(os.listdir(path)):
            directory = os.path.join(path, name)
            if os.path.isdir(directory):
                yield directory


def macro_value(match):
    return " ".join(re.sub(r"//.*", "", match.group(2)).split())


def header_macros():
    macros = collections.defaultdict(set)
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
        for name in files:
            if name.endswith(".h"):
                with open(os.path.join(dirpath, name), encoding="utf-8", errors="ignore") as header:
                    for line in header:
                        match = DEFINE.match(line)
                        if match:
                            macros[match.group(1)].add(macro_value(match))
    return macros


def scan(directory, headers):
    names = collections.defaultdict(set)
    macros = collections.defaultdict(dict)
    for dirpath, _, files in os.walk(directory):
        for name in files:
            if not name.endswith(".cpp"):
                continue
            path = os.path.join(dirpath, name)
            relative = os.path.relpath(path, ROOT).replace(os.sep, "/")
            with open(path, encoding="utf-8", errors="ignore") as source:
                for line in source:
                    for pattern in DECLARATIONS:
                        match = pattern.match(line)
                        if match:
                            names[match.group(1)].add(relative)
                    match = DEFINE.match(line)
                    if match:
                        macros[match.group(1)][relative] = macro_value(match)

    clashes = collections.defaultdict(set)
    for name, files in names.items():
        if len(files) > 1:
            for path in files:
                clashes[path].add(name)
    for name, values in macros.items():
        if len(values) > 1 and len(set(values.values())) > 1:
            for path in values:
                clashes[path].add("#define " + name)
        for path, value in values.items():
            if headers.get(name, set()) - {value}:
                clashes[path].add("#define " + name + " (differs from a header)")
    return clashes


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--why", action="store_true", help="show the clashing names")
    args = parser.parse_args()

    headers = header_macros()
    clashes = {}
    for directory in target_directories():
        clashes.update(scan(directory, headers))

    print("set(AU_UNITY_EXCLUDE")
    for path in sorted(clashes):
        suffix = "  # " + ", ".join(sorted(clashes[path])) if args.why else ""
        print("    " + path + suffix)
    print(")")


if __name__ == "__main__":
    main()
