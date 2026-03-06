#!/bin/sh

repo="imputnet/helium-linux"
api_base="https://api.github.com/repos/${repo}"
download_base="https://github.com/${repo}/releases/download"

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
    with_retry curl -s "${api_base}/releases/latest"
}

get_current_version() {
    grep -oE 'version = "[^"]+";' versions.nix | sed 's/version = "//;s/";//'
}

prefetch() {
    nix store prefetch-file --hash-type sha256 --json "$1" | jq -r '.hash'
}

main() {
    set -e

    echo "Fetching latest Helium release..."
    latest_release=$(get_latest_release)

    remote_version=$(echo "$latest_release" | jq -r '.tag_name')
    local_version=$(get_current_version)

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

    base_url="${download_base}/${remote_version}/helium-${remote_version}"

    echo "Prefetching new hashes..."
    new_appimage_aarch64=$(prefetch "${base_url}-arm64.AppImage")
    new_appimage_x86_64=$(prefetch "${base_url}-x86_64.AppImage")
    new_tarball_aarch64=$(prefetch "${base_url}-arm64_linux.tar.xz")
    new_tarball_x86_64=$(prefetch "${base_url}-x86_64_linux.tar.xz")

    echo "Updating versions.nix..."
    cat > versions.nix << EOF
{
  version = "$remote_version";
  appimage = {
    aarch64-linux = "$new_appimage_aarch64";
    x86_64-linux  = "$new_appimage_x86_64";
  };
  tarball = {
    aarch64-linux = "$new_tarball_aarch64";
    x86_64-linux  = "$new_tarball_x86_64";
  };
}
EOF

    echo "Updated Helium from $local_version to $remote_version"

    if $ci; then
        commit_message="chore(update): helium to $remote_version"
        echo "commit_message=$commit_message" >> "$GITHUB_OUTPUT"
        echo "should_update=true" >> "$GITHUB_OUTPUT"
    fi
}

main