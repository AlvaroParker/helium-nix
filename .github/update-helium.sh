#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

with_retry() {
    retries=5
    count=0
    output=""
    status=0

    while [ $count -lt $retries ]; do
        output=$("$@" 2>&1)
        status=$?

        if echo "$output" | grep -q 'Not Found'; then
            count=$((count + 1))
            echo "attempt $count/$retries: 404 Not Found encountered, retrying..." >&2
            sleep 1
        else
            echo "[TRACE] [cmd=$*] output: $output" 1>&2
            echo "$output" | tr -d '\000-\031'
            return $status
        fi
    done

    echo "max retries reached. last output: $output (cmd=$*)" >&2
    exit 1
}

get_latest_release() {
    with_retry curl -s "https://api.github.com/repos/imputnet/helium-linux/releases/latest"
}

get_current_version_from_flake() {
    grep -oE 'version = "[^"]+";' flake.nix | sed 's/version = "//;s/";//'
}

get_current_sha256_from_flake() {
    grep -oE 'sha256 = "[^"]+";' flake.nix | sed 's/sha256 = "//;s/";//'
}

main() {
    set -e

    echo "Fetching latest Helium release..."
    latest_release=$(get_latest_release)

    remote_version=$(echo "$latest_release" | jq -r '.tag_name')
    local_version=$(get_current_version_from_flake)

    echo "Checking version... local=$local_version remote=$remote_version"

    if [ "$local_version" = "$remote_version" ]; then
        echo "Local Helium version is up to date"
        if $only_check && $ci; then
            echo "should_update=false" >> "$GITHUB_OUTPUT"
        fi
        exit 0
    fi

    echo "Local Helium version is outdated, updating from $local_version to $remote_version"

    if $only_check; then
        echo "should_update=true" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    download_url="https://github.com/imputnet/helium-linux/releases/download/${remote_version}/helium-${remote_version}-x86_64.AppImage"

    echo "Prefetching new version..."
    prefetch_output=$(nix store prefetch-file --hash-type sha256 --json "$download_url")
    new_sha256=$(echo "$prefetch_output" | jq -r '.hash')

    echo "Updating flake.nix..."

    # Update version
    sed -i "s/version = \"[^\"]*\";/version = \"$remote_version\";/" flake.nix

    # Update SHA256
    old_sha256=$(get_current_sha256_from_flake)
    sed -i "s|sha256 = \"$old_sha256\";|sha256 = \"$new_sha256\";|" flake.nix

    echo "Updated Helium from $local_version to $remote_version"

    if $ci; then
        commit_message="chore(update): helium to $remote_version"
        echo "commit_message=$commit_message" >> "$GITHUB_OUTPUT"
        echo "should_update=true" >> "$GITHUB_OUTPUT"
    fi
}

main
