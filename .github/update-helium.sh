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
    echo "GETTING LATEST RELEASE" 1>&2
    if [ -n "$GH_TOKEN" ]; then
        echo "ATTEMPTING WITH TOKEN" 1>&2
        with_retry curl -s -H "Authorization: Bearer ${GH_TOKEN}" "${api_base}/releases/latest"
    else
        echo "GH_TOKEN NOT SET!!!!!!!" 1>&2
        with_retry curl -s "${api_base}/releases/latest"
    fi
}

# Parse a top-level string field from the GitHub API response using grep+sed.
# jq is intentionally avoided here: GitHub includes literal unescaped newlines
# in the release body field, which is invalid JSON that jq refuses to parse.
parse_field() {
    field="$1"
    grep -o "\"${field}\": *\"[^\"]*\"" | head -1 | sed "s/\"${field}\": *\"//;s/\"$//"
}

check_api_response() {
    response="$1"

    # A valid release object never has a top-level "message" field;
    # GitHub uses it exclusively for API errors (rate limiting, auth, etc.)
    message=$(echo "$response" | parse_field message)

    if [ -n "$message" ]; then
        echo "GitHub API error: $message" >&2
        exit 1
    fi
}

get_current_version() {
    grep -oE 'version = "[^"]+";' versions.nix | sed 's/version = "//;s/";//'
}

prefetch() {
    nix store prefetch-file --hash-type sha256 --json "$1" | jq -r '.hash'
}

write_versions_nix() {
    cat > versions.nix << EOF
{
  version = "$1";
  systems = {
    aarch64-linux = {
      appimage = "$2";
      tarball  = "$3";
    };
    x86_64-linux = {
      appimage = "$4";
      tarball  = "$5";
    };
  };
}
EOF
}

main() {
    set -e

    echo "Fetching latest Helium release..."
    latest_release=$(get_latest_release)

    # Bail out early if the API returned an error object instead of a release
    check_api_response "$latest_release"

    remote_version=$(echo "$latest_release" | parse_field tag_name)

    # A null or empty tag_name means the response was not a valid release,
    # even if it didn't contain a top-level .message field
    if [ -z "$remote_version" ] || [ "$remote_version" = "null" ]; then
        echo "Error: could not parse tag_name from GitHub API response:" >&2
        echo "$latest_release" >&2
        exit 1
    fi

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
    new_aarch64_appimage=$(prefetch "${base_url}-arm64.AppImage")
    new_aarch64_tarball=$(prefetch "${base_url}-arm64_linux.tar.xz")
    new_x86_64_appimage=$(prefetch "${base_url}-x86_64.AppImage")
    new_x86_64_tarball=$(prefetch "${base_url}-x86_64_linux.tar.xz")

    echo "Updating versions.nix..."
    write_versions_nix \
        "$remote_version" \
        "$new_aarch64_appimage" \
        "$new_aarch64_tarball" \
        "$new_x86_64_appimage" \
        "$new_x86_64_tarball"

    echo "Updated Helium from $local_version to $remote_version"

    if $ci; then
        commit_message="chore(update): helium to $remote_version"
        echo "commit_message=$commit_message" >> "$GITHUB_OUTPUT"
        echo "should_update=true" >> "$GITHUB_OUTPUT"
    fi
}

main