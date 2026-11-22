#!/usr/bin/env python3
"""Offline policy tests: every policy in policy/ must DENY the insecure
fixture and ALLOW the hardened fixture. No Azure subscription required.

Usage: python3 tests/run_tests.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def resolve(resource, field):
    """Resolve a policy field path to a list of values.

    Supports [*] array wildcards. Missing field -> [].
    """
    if field in ("type", "name", "scope"):
        return [resource.get(field)]
    values = [resource]
    for part in field.split("."):
        nxt = []
        for v in values:
            if part == "[*]":
                if isinstance(v, list):
                    nxt.extend(v)
            elif part.endswith("[*]"):
                # e.g. "containers[*]" — get the list and flatten it.
                key = part[:-3]
                if isinstance(v, dict) and isinstance(v.get(key), list):
                    nxt.extend(v[key])
            elif isinstance(v, dict) and part in v:
                nxt.append(v[part])
        values = nxt
        if not values:
            break
    return values


def like_match(pattern, value):
    if not isinstance(value, str):
        return False
    rx = re.escape(pattern).replace(r"\*", ".*").replace(r"\?", ".")
    return re.fullmatch(rx, value, re.IGNORECASE) is not None


def eval_leaf(cond, resource):
    values = resolve(resource, cond["field"])
    if "exists" in cond:
        return (len(values) > 0) == cond["exists"]
    if "equals" in cond:
        return any(v == cond["equals"] for v in values)
    if "notEquals" in cond:
        return not any(v == cond["notEquals"] for v in values)
    if "in" in cond:
        return any(v in cond["in"] for v in values)
    if "notIn" in cond:
        return not any(v in cond["notIn"] for v in values)
    if "like" in cond:
        return any(like_match(cond["like"], v) for v in values)
    if "notLike" in cond:
        return not any(like_match(cond["notLike"], v) for v in values)
    raise ValueError(f"Unsupported condition: {cond}")


def evaluate(cond, resource):
    if "allOf" in cond:
        return all(evaluate(c, resource) for c in cond["allOf"])
    if "anyOf" in cond:
        return any(evaluate(c, resource) for c in cond["anyOf"])
    if "not" in cond:
        return not evaluate(cond["not"], resource)
    return eval_leaf(cond, resource)


def load_json(path):
    with open(path) as f:
        return json.load(f)


def main():
    policies = sorted((ROOT / "policy").glob("*.json"))
    insecure = load_json(ROOT / "tests" / "fixtures" / "insecure.json")["resources"]
    hardened = load_json(ROOT / "tests" / "fixtures" / "hardened.json")["resources"]

    failures = []
    print(f"{'Policy':<32} {'Insecure':<10} {'Hardened':<10} Result")
    print("-" * 70)
    for p in policies:
        props = load_json(p)["properties"]
        assert props["rules"]["then"]["effect"] == "deny", f"{p.name}: effect must be deny"
        assert props["mode"] == "All", f"{p.name}: mode must be All"
        cond = props["rules"]["if"]
        denied_insecure = any(evaluate(cond, r) for r in insecure)
        denied_hardened = any(evaluate(cond, r) for r in hardened)
        ok = denied_insecure and not denied_hardened
        print(
            f"{p.stem:<32} "
            f"{'DENY' if denied_insecure else 'allow':<10} "
            f"{'DENY' if denied_hardened else 'allow':<10} "
            f"{'PASS' if ok else 'FAIL'}"
        )
        if not ok:
            failures.append(p.name)
    print("-" * 70)
    if failures:
        print(f"FAILED: {failures}")
        return 1
    print(f"All {len(policies)} policies deny insecure and allow hardened.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
