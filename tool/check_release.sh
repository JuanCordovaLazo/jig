#!/usr/bin/env bash
#
# Fails when the tag, the pubspecs, the constant and the changelogs disagree.
#
# The tag is the only address a consumer has: nothing here is published to pub.dev,
# so `ref: vX.Y.Z` is what installs the release. A tag that names a version the
# pubspecs do not declare installs code that is not the release it claims to be, and
# nothing notices until someone resolves it and gets the wrong tree.
#
# Usage: tool/check_release.sh v1.0.0
set -uo pipefail

tag=${1:-}
if [[ ! $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  printf 'usage: %s vX.Y.Z (got %s)\n' "$0" "'$tag'" >&2
  exit 2
fi
version=${tag#v}

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) || exit 1
cd "$root" || exit 1

failed=0

# Every workspace member declares the tagged version.
for pubspec in packages/*/pubspec.yaml apps/fixture/pubspec.yaml; do
  declared=$(grep -m1 '^version:' "$pubspec" | awk '{print $2}')
  if [[ $declared != "$version" ]]; then
    printf 'mismatch: %s declares %s, tag says %s\n' \
      "$pubspec" "${declared:-<none>}" "$version" >&2
    failed=1
  fi
done

# Every internal constraint accepts it, or the workspace cannot resolve.
for pubspec in packages/*/pubspec.yaml apps/fixture/pubspec.yaml; do
  while read -r name constraint; do
    if [[ $constraint != "^$version" ]]; then
      printf 'mismatch: %s declares %s %s, tag says ^%s\n' \
        "$pubspec" "$name" "$constraint" "$version" >&2
      failed=1
    fi
  done < <(grep -E '^  jig_[a-z_]+: \^' "$pubspec" | awk '{print $1, $2}')
done

# The version the frontends report is the version that was released.
if ! grep -qF "const String jigVersion = '$version';" \
  packages/jig_protocol/lib/jig_protocol.dart; then
  printf 'mismatch: jigVersion is not %s\n' "$version" >&2
  failed=1
fi

# The release is written down, once at the root and once per package.
for changelog in CHANGELOG.md packages/*/CHANGELOG.md; do
  if ! grep -qF "## $version" "$changelog"; then
    printf 'mismatch: %s has no section for %s\n' "$changelog" "$version" >&2
    failed=1
  fi
done

if (( failed )); then
  printf 'release check failed for %s\n' "$tag" >&2
  exit 1
fi

printf 'release check passed for %s\n' "$tag"
