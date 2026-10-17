#!/usr/bin/env bash
#
# Builds porelo-frontend as a .deb and a .rpm.
#
# Two things this script exists to get right, and they are the two acceptance criteria that are
# easy to fake:
#
#   * Dependencies are DERIVED FROM THE BINARY, never written down. A hand-written list goes stale
#     the first time Flutter changes what it links, and the failure is a package that installs and
#     then opens no window. `dpkg-shlibdeps` reads the ELF for the Debian side and gives version
#     floors with it; the RPM side takes the sonames straight out of the ELF, which is the same
#     thing rpm's own scanner would have produced.
#
#   * The build machine sets the floor. The bundle links the system GTK3 stack, so the GTK here is
#     the oldest GTK the package can run against. Build on the oldest distribution you intend to
#     support — for Porelo that means Ubuntu, never Fedora.
#
# Shell, not Java: Porelo's Java tooling builds no package from a native tree. The backend stamps
# its own with jdeb and rpm-maven-plugin and declares their dependencies by hand, and nothing in
# `porelo-release` derives them from ELF files or compares `~snapshot.<run>` versions.
# What this script does is call dpkg-shlibdeps, objdump and nfpm, native programs a JVM
# would only start in turn. What has to match the rest of Porelo is the package somebody installs,
# not the tool that wrote it. The one check shared with the rest of Porelo, the C library floor, is
# `porelo-release`'s `check-linkage`, as Porelo's own packages hold theirs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

base="${1:-$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//' | tr -d '[:space:]')}"
# `pubspec.yaml` says `-SNAPSHOT` until a release, as every other repository's version line does;
# the package's own word for that is `~snapshot.<run>`, so the suffix is not carried over.
base="${base%-SNAPSHOT}"

# Every build of `main` replaces the packages in a repository called `snapshots`, so each one has
# to supersede the last or `apt upgrade` has nothing to do and nobody ever moves off the build
# they first installed. The run number does that; `~` keeps the whole series below the eventual
# release.
#
# Matching the backend's `0.4.0~snapshot.<run>` exactly, so both sets of packages sort the same
# way in one repository. The counters are separate on purpose — a package only ever has to
# supersede its own predecessor.
run="${SNAPSHOT_RUN:-0}"
version="$base~snapshot.$run"
# A release, built from its version tag, is the version itself.
if [ "${RELEASE:-0}" = 1 ]; then version="$base"; fi
out="${OUT_DIR:-build/packages}"
bundle="build/linux/x64/release/bundle"
nfpm="${NFPM:-nfpm}"

say() { printf '\n== %s\n' "$*"; }

command -v "$nfpm" >/dev/null || {
    echo "nfpm is not on PATH. It is one static binary:" >&2
    echo "  https://github.com/goreleaser/nfpm/releases" >&2
    exit 1
}

# Asked of dpkg on the version actually built, rather than reasoned about. The trap is lexical
# comparison: if `10` did not beat `9` the scheme would keep working for nine builds and then
# quietly stop.
say "Checking the version supersedes the last one: $version"
case "$version" in
*~SNAPSHOT | *-SNAPSHOT)
    echo "a flat snapshot never supersedes the last one: $version" >&2
    exit 1
    ;;
esac
# A release is the version itself, so the ordering of snapshots says nothing about it.
if [ "${RELEASE:-0}" != 1 ]; then
    dpkg --compare-versions "$version" lt "$base" ||
        {
            echo "$version should sort below the release $base" >&2
            exit 1
        }
    dpkg --compare-versions "$version" lt "$base~snapshot.$((run + 1))" ||
        {
            echo "$version should sort below the next build" >&2
            exit 1
        }
    dpkg --compare-versions "$base~snapshot.9" lt "$base~snapshot.10" ||
        {
            echo "digit runs are being compared lexically; build 10 would not beat build 9" >&2
            exit 1
        }
fi

say "Building the release bundle"
flutter build linux --release

test -x "$bundle/porelo_frontend" || {
    echo "no bundle at $bundle" >&2
    exit 1
}

# The ELF objects that decide what this package needs: the launcher and everything shipped beside
# it. libapp.so is our own AOT-compiled Dart and libflutter_linux_gtk.so is vendored, so neither is
# a dependency — but both are scanned, because what *they* link is.
mapfile -t objects < <(
    printf '%s\n' "$bundle/porelo_frontend"
    find "$bundle/lib" -name '*.so' | sort
)

say "Deriving Debian dependencies from ${#objects[@]} ELF objects"
# Staged into a package tree first, and not out of tidiness: libflutter_linux_gtk.so has an RPATH
# of $ORIGIN, which dpkg-shlibdeps can only resolve against a real tree with a DEBIAN/ directory
# in it. Run against the build directory it warns and analyzes less than it should.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
installed="$staging/debian/porelo-frontend/usr/lib/porelo-frontend"
mkdir -p "$installed" "$staging/debian/porelo-frontend/DEBIAN"
printf 'Source: porelo-frontend\n\nPackage: porelo-frontend\nArchitecture: amd64\n' \
    >"$staging/debian/control"
cp -r "$bundle/." "$installed/"

# -O prints to stdout instead of writing debian/substvars; --ignore-missing-info keeps a vendored
# .so with no shlibs entry from failing the run rather than being skipped.
depends="$(
    cd "$staging" && dpkg-shlibdeps -O --ignore-missing-info \
        debian/porelo-frontend/usr/lib/porelo-frontend/porelo_frontend \
        debian/porelo-frontend/usr/lib/porelo-frontend/lib/*.so 2>/dev/null |
        sed -n 's/^shlibs:Depends=//p'
)"
test -n "$depends" || {
    echo "dpkg-shlibdeps derived nothing; refusing to ship a deb with no dependencies" >&2
    exit 1
}
echo "$depends"

say "Deriving RPM requires from the same objects"
# rpm's own scanner would emit soname requires; nfpm does not run it, so they come straight out of
# the ELF. Anything shipped inside this package is dropped: a package must not require itself.
mapfile -t shipped < <(find "$bundle/lib" -name '*.so' -printf '%f\n')
requires="$(
    for object in "${objects[@]}"; do
        objdump -p "$object" | awk '/NEEDED/ {print $2}'
    done | sort -u | while read -r soname; do
        for own in "${shipped[@]}"; do
            [ "$soname" = "$own" ] && continue 2
        done
        echo "${soname}()(64bit)"
    done
)"
test -n "$requires" || {
    echo "no sonames found; refusing to ship an rpm with no dependencies" >&2
    exit 1
}

say "Holding the C library floor"
# The floor both packages promise is the one dpkg-shlibdeps derived, `libc6 (>= …)`; the RPM side
# says it as rpm's own scanner would, `libc.so.6(GLIBC_…)(64bit)`. Porelo's shared check holds it:
# no object may need a newer glibc symbol than that floor, and the floor may not rise above Debian
# 13's glibc 2.41, or the package would no longer install on a system Porelo supports. Both are
# refused here, before anything is published. `--declared-only` leaves GTK and the bundle's own
# libraries to the dependencies derived above.
ceiling="${GLIBC_CEILING:-2.41}"
floor="$(echo "$depends" | grep -oE 'libc6 \(>= [0-9.]+' | grep -oE '[0-9][0-9.]*$' || true)"
test -n "$floor" || {
    echo "dpkg-shlibdeps named no libc6 floor; refusing to guess the C library floor" >&2
    exit 1
}
tools="${JDK_CP:-build/jdk-cp.txt}"
test -s "$tools" || {
    echo "no $tools: resolve Porelo's tools first (mvnw -Pci-tools dependency:build-classpath)" >&2
    exit 1
}
java -cp "$(cat "$tools")" org.fuin.porelo.release.Main check-linkage --declared-only \
    --declare "libc.so.6=GLIBC:$floor" --ceiling "GLIBC=$ceiling" "${objects[@]}"
requires="$(printf '%s\nlibc.so.6(GLIBC_%s)(64bit)' "$requires" "$floor")"
echo "$requires"

say "Writing the nfpm configuration"
mkdir -p "$out"
config="$out/nfpm.yaml"
{
    sed -e "s|@VERSION@|$version|g" packaging/nfpm.yaml.in
    echo "depends:"
    # One entry per constraint. `dpkg-shlibdeps` answers them comma-separated on one line.
    echo "$depends" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | while read -r one; do
        [ -n "$one" ] && printf '  - %s\n' "\"$one\""
    done
    echo "overrides:"
    echo "  rpm:"
    echo "    depends:"
    echo "$requires" | while read -r one; do
        [ -n "$one" ] && printf '      - %s\n' "\"$one\""
    done
} >"$config"

say "Packaging"
"$nfpm" package --config "$config" --packager deb --target "$out"
"$nfpm" package --config "$config" --packager rpm --target "$out"

say "What was built"
ls -1 "$out"/*.deb "$out"/*.rpm
