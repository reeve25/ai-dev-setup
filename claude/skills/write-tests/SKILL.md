---
name: write-tests
description: Write focused tests for a file, function, or recent change using the project's existing test setup, then run them. Use when asked to add tests, test this, or do test-first development.
---

# Write tests

1. Find the existing test setup first: `pytest.ini`/`pyproject.toml`/`tests/`, `package.json` scripts, `Makefile` targets, `*_test.*`/`test_*.*` files. Reuse its framework and style. If there is none: Python gets a plain `test_<module>.py` run with `python -m pytest` (or an assert-based `__main__` self-check if pytest isn't installed); JS gets `node --test`.
2. Read the code under test and list its behaviors: the happy path, edge cases (empty, zero, None, boundaries, unicode), and error paths.
3. Write the fewest tests that would catch a real regression. One assert idea per test. Name tests after the behavior (`test_empty_roster_returns_no_trades`).
4. No network, no real API keys, no live DB in unit tests; stub at the boundary. Flag a test that must hit a live service (like `arb.py selfcheck`).
5. Test-first mode (user says "TDD" or "test first"): write the failing test, run it and show it fail, then implement, then show it pass.
6. Run the tests and paste the actual pass/fail summary. If a test fails because the code is wrong, report it; don't weaken the test to make it pass.
