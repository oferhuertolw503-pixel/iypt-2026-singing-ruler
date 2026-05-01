#!/usr/bin/env python3
"""Convert ChatGPT-style markdown into VS Code-friendly markdown."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from dataclasses import dataclass

FENCE_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})")
CITATION_RE = re.compile(r"\(\[([^\]]+)\]\[(\d+)\]\)")
ESCAPED_INLINE_MATH_RE = re.compile(r"\\\((.+?)\\\)")
PAREN_GROUP_RE = re.compile(r"(?<!\])\(([^()\n]{1,100})\)")
MATH_WRAPPER_POWER_RE = re.compile(r"\(\$([^$\n]+)\$(\^[^) \t]+)\)")
MATH_WRAPPER_RE = re.compile(r"\(\$([^$\n]+)\$\)")
CHINESE_RE = re.compile(r"[\u4e00-\u9fff]")


@dataclass
class Stats:
    display_math_blocks: int = 0
    inline_math_escaped: int = 0
    inline_math_parenthesized: int = 0
    citation_unwrapped: int = 0
    math_wrapper_power_fixed: int = 0
    math_wrapper_removed: int = 0
    trailing_whitespace_trimmed: int = 0


def is_math_candidate(expr: str) -> bool:
    value = expr.strip()
    if not value:
        return False
    if CHINESE_RE.search(value):
        return False
    if "$" in value:
        return False
    if "http://" in value or "https://" in value:
        return False
    if not re.search(r"[A-Za-z\\]", value):
        return False

    if re.search(r"[\\_^=/*{}]", value):
        return True
    if "," in value and re.fullmatch(r"[A-Za-z0-9.,\s-]+", value):
        return True
    if "+" in value or "-" in value:
        return True
    return False


def transform_inline_line(line: str, stats: Stats) -> str:
    line, n = CITATION_RE.subn(r"[\1][\2]", line)
    stats.citation_unwrapped += n

    def escaped_to_dollar(match: re.Match[str]) -> str:
        stats.inline_math_escaped += 1
        return f"${match.group(1).strip()}$"

    line = ESCAPED_INLINE_MATH_RE.sub(escaped_to_dollar, line)

    def paren_to_dollar(match: re.Match[str]) -> str:
        expr = match.group(1).strip()
        if is_math_candidate(expr):
            stats.inline_math_parenthesized += 1
            return f"${expr}$"
        return match.group(0)

    line = PAREN_GROUP_RE.sub(paren_to_dollar, line)

    line, n = MATH_WRAPPER_POWER_RE.subn(r"$\1\2$", line)
    stats.math_wrapper_power_fixed += n

    line, n = MATH_WRAPPER_RE.subn(r"$\1$", line)
    stats.math_wrapper_removed += n

    return line


def convert_markdown(text: str, stats: Stats) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    out: list[str] = []

    in_code_fence = False
    fence_char = ""
    fence_len = 0
    i = 0

    while i < len(lines):
        line = lines[i]
        fence_match = FENCE_RE.match(line)

        if fence_match:
            marker = fence_match.group(1)
            marker_char = marker[0]
            marker_len = len(marker)

            if not in_code_fence:
                in_code_fence = True
                fence_char = marker_char
                fence_len = marker_len
            elif marker_char == fence_char and marker_len >= fence_len:
                in_code_fence = False
                fence_char = ""
                fence_len = 0

            out.append(line)
            i += 1
            continue

        if in_code_fence:
            out.append(line)
            i += 1
            continue

        stripped = line.strip()
        if stripped in ("[", "\\["):
            matched = False
            j = i + 1
            while j < len(lines):
                if FENCE_RE.match(lines[j]):
                    break
                if lines[j].strip() in ("]", "\\]"):
                    out.append("$$")
                    for k in range(i + 1, j):
                        formula_line = lines[k].rstrip(" \t")
                        if formula_line != lines[k]:
                            stats.trailing_whitespace_trimmed += 1
                        out.append(formula_line)
                    out.append("$$")
                    stats.display_math_blocks += 1
                    i = j + 1
                    matched = True
                    break
                j += 1
            if matched:
                continue

        converted = transform_inline_line(line, stats)
        trimmed = converted.rstrip(" \t")
        if trimmed != converted:
            stats.trailing_whitespace_trimmed += 1
        out.append(trimmed)
        i += 1

    result = "\n".join(out)
    if not result.endswith("\n"):
        result += "\n"
    return result


def lint_chatgpt_patterns(text: str) -> list[str]:
    issues: list[str] = []
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = normalized.split("\n")

    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped in ("[", "\\[", "]", "\\]"):
            issues.append(f"line {idx}: isolated math bracket '{stripped}'")
        if CITATION_RE.search(line):
            issues.append(f"line {idx}: wrapped reference style '([text][n])'")
        if "\\(" in line or "\\)" in line:
            issues.append(f"line {idx}: escaped inline math '\\(...\\)'")
    return issues


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Convert ChatGPT markdown patterns to VS Code-friendly markdown. "
            "By default, writes '<input>.vscode.md'."
        )
    )
    parser.add_argument("input", type=pathlib.Path, help="Input markdown file")
    parser.add_argument("-o", "--output", type=pathlib.Path, help="Output markdown file")
    parser.add_argument("--in-place", action="store_true", help="Rewrite input file")
    parser.add_argument("--no-backup", action="store_true", help="Disable backup when --in-place")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Only run pattern checks. Exit non-zero if ChatGPT-style patterns remain.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path: pathlib.Path = args.input

    if args.in_place and args.output:
        print("--in-place cannot be used together with --output", file=sys.stderr)
        return 2

    if not input_path.exists():
        print(f"input file not found: {input_path}", file=sys.stderr)
        return 2

    original = input_path.read_text(encoding="utf-8")

    if args.check:
        issues = lint_chatgpt_patterns(original)
        if issues:
            print(f"CHECK FAILED ({len(issues)} issues):")
            for issue in issues:
                print(f"- {issue}")
            return 1
        print("CHECK PASSED: no target ChatGPT-style patterns detected.")
        return 0

    stats = Stats()
    converted = convert_markdown(original, stats)

    if args.in_place:
        output_path = input_path
    elif args.output:
        output_path = args.output
    else:
        output_path = input_path.with_name(f"{input_path.stem}.vscode{input_path.suffix}")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    if args.in_place and not args.no_backup:
        backup_path = input_path.with_suffix(input_path.suffix + ".bak")
        backup_path.write_text(original, encoding="utf-8")
        print(f"backup written: {backup_path}")

    output_path.write_text(converted, encoding="utf-8")

    print(f"input : {input_path}")
    print(f"output: {output_path}")
    print("changes:")
    print(f"- display math blocks converted: {stats.display_math_blocks}")
    print(f"- escaped inline math converted: {stats.inline_math_escaped}")
    print(f"- parenthesized math converted: {stats.inline_math_parenthesized}")
    print(f"- wrapped references unwrapped: {stats.citation_unwrapped}")
    print(f"- wrapped math powers fixed: {stats.math_wrapper_power_fixed}")
    print(f"- wrapped math parentheses removed: {stats.math_wrapper_removed}")
    print(f"- trailing whitespaces trimmed: {stats.trailing_whitespace_trimmed}")

    post_issues = lint_chatgpt_patterns(converted)
    if post_issues:
        print(f"post-check: {len(post_issues)} issue(s) still detected", file=sys.stderr)
        for issue in post_issues[:20]:
            print(f"- {issue}", file=sys.stderr)
        if len(post_issues) > 20:
            print(f"- ... {len(post_issues) - 20} more", file=sys.stderr)
        return 1

    print("post-check: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
