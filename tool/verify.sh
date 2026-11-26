#!/usr/bin/env bash
#
# The whole gate in one command: analysis plus every suite that exists.
#
# This mirrors the `analyze` and `test` jobs in .github/workflows/ci.yml; keep the
# two in sync. Run it from anywhere.
#
# Exit status is 0 only when everything passed. Each step runs to completion so one
# run reports every breakage instead of the first, and nothing is piped: a masked
# exit code would make the gate unable to fail, which is the whole point of it.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) || exit 1
cd "$root" || exit 1

failed=()

run_in() {
  local dir=$1
  local label=$2
  shift 2
  printf '\n== %s\n' "$label"
  if ( cd "$dir" && "$@" ); then
    return 0
  fi
  failed+=("$label")
}

printf '== resolving workspace\n'
if ! dart pub get; then
  echo 'dart pub get failed; nothing else can run.' >&2
  exit 1
fi

run_in . 'dart analyze' dart analyze .
run_in apps/fixture 'flutter analyze (fixture)' flutter analyze
run_in packages/jig_protocol 'test jig_protocol' dart test
run_in packages/jig_driver 'test jig_driver' dart test
run_in packages/jig_cli 'test jig_cli' dart test
run_in packages/jig_mcp 'test jig_mcp' dart test
run_in packages/jig_flutter 'test jig_flutter' flutter test
run_in apps/fixture 'test fixture verbs' flutter test
# Spawns the server and speaks stdio JSON-RPC to it. The unit tests drive `handle`
# with maps; only a process can show that the handshake does not wait on the app and
# that a handler's exception does not end it.
run_in . 'mcp smoke (wire)' dart run tool/mcp_smoke.dart

if (( ${#failed[@]} )); then
  printf '\nFAILED (%d):\n' "${#failed[@]}"
  printf '  - %s\n' "${failed[@]}"
  exit 1
fi

printf '\nAll checks passed.\n'
