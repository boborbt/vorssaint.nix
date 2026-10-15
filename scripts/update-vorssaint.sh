#!/usr/bin/env bash
set -euo pipefail

api_url="https://api.github.com/repos/vorssaint/vorssaint-utils/releases/latest"
check_only=false

usage() {
  cat <<'EOF'
Usage: scripts/update-vorssaint.sh [--check]

Check the repository against the latest stable Vorssaint release and update
package.nix and the pinned Defaults.swift link when they are out of date.

  --check   check alignment without modifying files; exit 1 when outdated
  -h, --help
EOF
}

case "${1:-}" in
  "") ;;
  --check) check_only=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_file="$repo_root/package.nix"
readme_file="$repo_root/README.md"

for command in curl git jq nix sed grep mktemp cmp mv; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Errore: comando richiesto non trovato: %s\n' "$command" >&2
    exit 1
  fi
done

cd "$repo_root"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/update-vorssaint.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

release_json="$tmp_dir/release.json"
curl --fail --silent --show-error --location --retry 3 \
  --header 'Accept: application/vnd.github+json' \
  --header 'User-Agent: vorssaint.nix-update-script' \
  "$api_url" > "$release_json"

release_tag=$(jq -er '.tag_name // empty' "$release_json")
if [[ ! "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Errore: tag release upstream non valido: %s\n' "$release_tag" >&2
  exit 1
fi
version=${release_tag#v}
asset_name="Vorssaint-${version}.dmg"

asset_count=$(jq --arg name "$asset_name" '[.assets[] | select(.name == $name)] | length' "$release_json")
if [[ "$asset_count" != 1 ]]; then
  printf 'Errore: atteso un solo asset %s, trovati %s.\n' "$asset_name" "$asset_count" >&2
  exit 1
fi

asset_url=$(jq -er --arg name "$asset_name" \
  '[.assets[] | select(.name == $name)][0].browser_download_url // empty' \
  "$release_json")
asset_digest=$(jq -r --arg name "$asset_name" \
  '[.assets[] | select(.name == $name)][0].digest // ""' "$release_json")

if [[ -n "$asset_digest" ]]; then
  if [[ ! "$asset_digest" =~ ^sha256:[[:xdigit:]]{64}$ ]]; then
    printf 'Errore: digest SHA-256 upstream non valido: %s\n' "$asset_digest" >&2
    exit 1
  fi
  upstream_hash=$(nix hash convert --hash-algo sha256 --from base16 --to sri \
    "${asset_digest#sha256:}")
else
  printf "Digest API assente; scarico l'asset per calcolare l'hash.\n" >&2
  asset_file="$tmp_dir/$asset_name"
  curl --fail --silent --show-error --location --retry 3 \
    --output "$asset_file" "$asset_url"
  upstream_hash=$(nix hash file --type sha256 --sri "$asset_file")
fi

count=$(grep -Ec '^  version = "[^"]+";$' "$package_file" || true)
if [[ "$count" != 1 ]]; then
  printf 'Errore: impossibile individuare univocamente version in %s.\n' "$package_file" >&2
  exit 1
fi
current_version=$(sed -nE 's/^  version = "([^"]+)";$/\1/p' "$package_file")

count=$(grep -Ec '^    hash = "[^"]+";$' "$package_file" || true)
if [[ "$count" != 1 ]]; then
  printf 'Errore: impossibile individuare univocamente hash in %s.\n' "$package_file" >&2
  exit 1
fi
current_hash=$(sed -nE 's/^    hash = "([^"]+)";$/\1/p' "$package_file")

count=$(grep -Ec 'github\.com/vorssaint/vorssaint-utils/blob/v[0-9]+\.[0-9]+\.[0-9]+/Sources/Vorssaint/Core/Defaults\.swift' "$readme_file" || true)
if [[ "$count" != 1 ]]; then
  printf 'Errore: impossibile individuare univocamente il link Defaults.swift in %s.\n' "$readme_file" >&2
  exit 1
fi
current_readme_version=$(sed -nE \
  's#.*github\.com/vorssaint/vorssaint-utils/blob/v([0-9]+\.[0-9]+\.[0-9]+)/Sources/Vorssaint/Core/Defaults\.swift.*#\1#p' \
  "$readme_file")

if [[ "$current_version" == "$version" && "$current_hash" == "$upstream_hash" && \
      "$current_readme_version" == "$version" ]]; then
  printf 'Repository allineato a Vorssaint %s.\n' "$version"
  exit 0
fi

printf 'Repository non allineato: locale %s/%s, upstream %s/%s.\n' \
  "$current_version" "$current_hash" "$version" "$upstream_hash"
if [[ "$current_readme_version" != "$version" ]]; then
  printf 'Link README Defaults.swift: locale %s, upstream %s.\n' \
    "$current_readme_version" "$version"
fi

if [[ "$check_only" == true ]]; then
  exit 1
fi

if ! git diff --quiet -- "$package_file" "$readme_file" || \
   ! git diff --cached --quiet -- "$package_file" "$readme_file"; then
  printf 'Errore: package.nix o README.md contiene modifiche locali; aggiornamento annullato.\n' >&2
  exit 1
fi

updated_package="$tmp_dir/package.nix"
sed -E \
  -e "s|^  version = \"[^\"]+\";\$|  version = \"$version\";|" \
  -e "s|^    hash = \"[^\"]+\";\$|    hash = \"$upstream_hash\";|" \
  "$package_file" > "$updated_package"

updated_readme="$tmp_dir/README.md"
sed -E \
  "s|github\\.com/vorssaint/vorssaint-utils/blob/v[0-9]+\\.[0-9]+\\.[0-9]+/Sources/Vorssaint/Core/Defaults\\.swift|github.com/vorssaint/vorssaint-utils/blob/v$version/Sources/Vorssaint/Core/Defaults.swift|" \
  "$readme_file" > "$updated_readme"

if ! cmp -s "$package_file" "$updated_package"; then
  mv "$updated_package" "$package_file"
fi
if ! cmp -s "$readme_file" "$updated_readme"; then
  mv "$updated_readme" "$readme_file"
fi

printf 'Repository aggiornato a Vorssaint %s.\n' "$version"
