#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

SOURCE_APK_FILE="genki.apkg"
RELEASE_APKG_FILE="$TMP_DIR/more_genki.apkg"
REPO="parsodark/genki_anki_deck_generator"

check_gh_installed() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: GitHub CLI (gh) is not installed." >&2
        exit 1
    fi
}

check_gh_authenticated() {
    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: GitHub CLI is not authenticated. Run 'gh auth login'." >&2
        exit 1
    fi
}

check_apkg_exists() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: $file not found." >&2
        exit 1
    fi
}

ask_version() {
    read -rp "Enter release version (a.b.c): " VERSION

    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in the format a.b.c (e.g. 1.2.3)." >&2
        exit 1
    fi

    TAG="v${VERSION}"
}

check_tag_does_not_exist() {
    local tag="$1"

    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
        echo "Error: Git tag $tag already exists." >&2
        exit 1
    fi
}

check_release_does_not_exist() {
    local tag="$1"

    if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
        echo "Error: GitHub release $tag already exists." >&2
        exit 1
    fi
}

create_tag() {
    local tag="$1"
    local version="$2"

    git tag -a "$tag" -m "Release $version"
}

push_tag() {
    local tag="$1"

    git push origin "$tag"
}

create_release() {
    local tag="$1"
    local source_file="$2"
    local release_file="$3"

    cp "$source_file" "$release_file"

    gh release create "$tag" "$release_file" \
        --title "$tag" \
        --repo "$REPO" \
        --generate-notes
}

main() {
    check_gh_installed
    check_gh_authenticated
    check_apkg_exists "$SOURCE_APK_FILE"
    ask_version

    check_tag_does_not_exist "$TAG"
    check_release_does_not_exist "$TAG"

    create_tag "$TAG" "$VERSION"
    push_tag "$TAG"
    create_release "$TAG" "$SOURCE_APK_FILE" "$RELEASE_APKG_FILE"

    echo "Release $TAG created successfully."
}

main "$@"
