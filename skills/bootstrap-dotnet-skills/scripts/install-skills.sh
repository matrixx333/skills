#!/usr/bin/env bash
#
# install-skills.sh — install skills from a single source repo (default: this
# repo, matrixx333/skills) into a Claude Code skills scope.
#
# There is no manifest file: every skill is discovered by walking the source
# repo's skills/**/SKILL.md, so both root-level skills (skills/design-patterns)
# and nested ones (skills/dotnet-skills/testcontainers) are found without
# anything declaring where each one lives. Use --skills / --exclude to narrow
# the set at invocation time instead of maintaining a committed list.
#
# Requires: git, coreutils. jq is used when present but is NOT required —
# Git Bash on Windows does not ship it.
#
# stdout is a single JSON object and nothing else. All logging goes to stderr.
#
set -Eeuo pipefail

readonly NAME_PATTERN='^[a-z0-9][a-z0-9-]*$'
readonly DEFAULT_REPO='https://github.com/matrixx333/skills.git'
readonly SELF_NAME='bootstrap-dotnet-skills'

repo="$DEFAULT_REPO"
ref_override=""
scope="${HOME}/.claude/skills"
dry_run=0
force=0
emit_catalog=0
include=()
exclude=()

# --------------------------------------------------------------------------
# logging / errors
# --------------------------------------------------------------------------

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; trap - ERR; exit 1; }

tmp_dir=""
drop_tmp() {
    [[ -n "$tmp_dir" && -d "$tmp_dir" ]] || return 0
    # git leaves pack files read-only; on Windows a plain `rm -rf` then fails
    # partway through and strands the clone on disk.
    chmod -R u+w "$tmp_dir" 2>/dev/null || true
    rm -rf "$tmp_dir" || warn "could not remove temp clone: $tmp_dir"
    log "removed temp clone"
    tmp_dir=""
}

cleanup() { local rc=$?; drop_tmp; return $rc; }
trap cleanup EXIT
trap 'rc=$?; trap - ERR; printf "[%s] ERROR: unexpected failure at line %s (exit %d)\n" \
    "$(date +%H:%M:%S)" "$LINENO" "$rc" >&2; exit $rc' ERR

usage() {
    cat <<EOF
Usage: install-skills.sh [options]

  --repo URL        source repo to install from (default: $DEFAULT_REPO)
  --ref REF         branch/tag to install (default: the remote's own default
                    branch, resolved via git ls-remote --symref)
  --scope PATH      install target   (default: \$HOME/.claude/skills)
  --skills NAME     only install this skill; repeatable. Default: every skill
                    discovered under skills/**/SKILL.md, except $SELF_NAME
                    itself (pass --skills $SELF_NAME to include it anyway).
  --exclude NAME    drop this skill from whatever set was selected; repeatable.
  --dry-run         resolve and report, but write nothing
  --force           ignore the lockfile; reinstall everything regardless
  --emit-catalog    print installed skills with their descriptions, as JSON
  -h, --help        show this message

Emits a JSON summary on stdout. Logging goes to stderr.
EOF
}

# --------------------------------------------------------------------------
# argument parsing
# --------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)          [[ $# -ge 2 ]] || die "--repo needs a value";    repo="$2";        shift 2 ;;
        --ref)           [[ $# -ge 2 ]] || die "--ref needs a value";     ref_override="$2"; shift 2 ;;
        --scope)         [[ $# -ge 2 ]] || die "--scope needs a value";  scope="$2";        shift 2 ;;
        --skills)        [[ $# -ge 2 ]] || die "--skills needs a value"; include+=("$2");   shift 2 ;;
        --exclude)       [[ $# -ge 2 ]] || die "--exclude needs a value"; exclude+=("$2");  shift 2 ;;
        --dry-run)       dry_run=1; shift ;;
        --force)         force=1;   shift ;;
        --emit-catalog)  emit_catalog=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        *)               usage >&2; die "unknown option: $1" ;;
    esac
done

command -v git >/dev/null 2>&1 || die "git is required but was not found on PATH"

# --------------------------------------------------------------------------
# JSON helpers (hand-rolled: jq is optional, see header)
# --------------------------------------------------------------------------

json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g'
}

# Pull the frontmatter description out of a SKILL.md. It may be a folded
# multi-line YAML scalar, so read from `description:` until the next top-level
# key or the closing ---, then collapse whitespace and strip quotes.
skill_description() {
    awk '
        NR==1 && $0=="---" { infm=1; next }
        infm && $0=="---"  { exit }
        infm && /^description:[[:space:]]*/ {
            sub(/^description:[[:space:]]*/, ""); buf=$0; grab=1; next
        }
        grab && /^[a-zA-Z_-]+:[[:space:]]/ { grab=0 }
        grab { sub(/^[[:space:]]+/, " "); buf=buf $0 }
        END { gsub(/[[:space:]]+/, " ", buf); gsub(/^[ '"'"'"]+|[ '"'"'"]+$/, "", buf); print buf }
    ' "$1"
}

readonly lockfile_path="${scope}/.bootstrap-dotnet-skills-lock.json"

lock_field() {
    [[ -f "$lockfile_path" ]] || return 0
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$lockfile_path" | head -1
}

lock_tree_for() {
    [[ -f "$lockfile_path" ]] || return 0
    sed -n "s/.*\"name\"[[:space:]]*:[[:space:]]*\"$1\"[[:space:]]*,[[:space:]]*\"tree\"[[:space:]]*:[[:space:]]*\"\([0-9a-f]*\)\".*/\1/p" \
        "$lockfile_path" | head -1
}

lock_skill_names() {
    [[ -f "$lockfile_path" ]] || return 0
    grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$lockfile_path" \
        | sed 's/.*"\([^"]*\)"$/\1/' | sort
}

# --------------------------------------------------------------------------
# --emit-catalog: scan an already-installed scope directly, no lockfile needed
# beyond repo/ref/commit provenance.
# --------------------------------------------------------------------------

if [[ $emit_catalog -eq 1 ]]; then
    lf_repo="$(lock_field repo)"
    lf_ref="$(lock_field ref)"
    lf_commit="$(lock_field commit)"
    entries=""
    while IFS= read -r skill_md; do
        [[ -n "$skill_md" ]] || continue
        name="$(basename "$(dirname "$skill_md")")"
        desc="$(skill_description "$skill_md")"
        [[ -n "$entries" ]] && entries+=","
        entries+=$'\n    {"name": "'"$name"'", "description": "'"$(json_escape "$desc")"'"}'
    done < <(find "$scope" -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | sort)
    [[ -n "$entries" ]] && entries+=$'\n  '
    printf '{\n  "scope": "%s",\n  "repo": "%s",\n  "ref": "%s",\n  "commit": "%s",\n  "skills": [%s]\n}\n' \
        "$(json_escape "$scope")" "$(json_escape "$lf_repo")" "$(json_escape "$lf_ref")" \
        "$(json_escape "$lf_commit")" "$entries"
    exit 0
fi

# --------------------------------------------------------------------------
# resolve ref, precheck (one network call, no clone)
# --------------------------------------------------------------------------

detect_default_branch() {
    git ls-remote --symref "$repo" HEAD 2>/dev/null \
        | sed -n 's#^ref: refs/heads/\([^[:space:]]*\).*#\1#p' | head -1
}

ref="$ref_override"
[[ -n "$ref" ]] || ref="$(detect_default_branch)"
[[ -n "$ref" ]] || die "could not resolve a default branch for $repo"

log "installing from $repo@$ref into $scope"

remote_sha="$(git ls-remote "$repo" "$ref" | awk 'NR==1{print $1}')"
[[ -n "$remote_sha" ]] || die "ref '$ref' not found in $repo"
log "remote $ref is at ${remote_sha:0:12}"

# --------------------------------------------------------------------------
# clone (outside the project tree, removed by drop_tmp/the EXIT trap)
# --------------------------------------------------------------------------

tmp_dir="$(mktemp -d)"
log "cloning $repo@$ref"
git clone --quiet --depth 1 --branch "$ref" "$repo" "$tmp_dir" \
    || die "clone failed: $repo@$ref"
commit="$(git -C "$tmp_dir" rev-parse HEAD)"
log "cloned at ${commit:0:12}"

# --------------------------------------------------------------------------
# discover every skill under skills/**/SKILL.md — this is what lets a
# root-level skill (skills/design-patterns) and a nested one
# (skills/dotnet-skills/testcontainers) both resolve without a manifest
# declaring where each one lives.
# --------------------------------------------------------------------------

[[ -d "${tmp_dir}/skills" ]] || die "no skills/ directory in $repo@$ref"

discovered_names=() discovered_rel=()
while IFS= read -r -d '' skill_md; do
    rel="${skill_md#"${tmp_dir}"/}"
    rel="$(dirname "$rel")"
    name="$(basename "$rel")"
    [[ "$name" =~ $NAME_PATTERN ]] || die "invalid skill directory name: '$name' (must match $NAME_PATTERN)"
    discovered_names+=("$name")
    discovered_rel+=("$rel")
done < <(find "${tmp_dir}/skills" -mindepth 1 -name SKILL.md -print0 | sort -z)

[[ ${#discovered_names[@]} -gt 0 ]] || die "no skills discovered under ${tmp_dir}/skills"

dupes="$(printf '%s\n' "${discovered_names[@]}" | sort | uniq -d)"
[[ -z "$dupes" ]] || die "duplicate skill names discovered: $(printf '%s ' $dupes)"

# --------------------------------------------------------------------------
# apply --skills / --exclude, and the default self-exclusion
# --------------------------------------------------------------------------

rel_for() {
    local want="$1" i
    for i in "${!discovered_names[@]}"; do
        [[ "${discovered_names[$i]}" == "$want" ]] && { printf '%s' "${discovered_rel[$i]}"; return 0; }
    done
    return 1
}

selected_names=()
if [[ ${#include[@]} -gt 0 ]]; then
    for name in "${include[@]}"; do
        rel_for "$name" >/dev/null || die "requested skill not found in $repo@$ref: $name"
        selected_names+=("$name")
    done
else
    for name in "${discovered_names[@]}"; do
        [[ "$name" == "$SELF_NAME" ]] && continue
        selected_names+=("$name")
    done
fi

if [[ ${#exclude[@]} -gt 0 ]]; then
    filtered=()
    for name in "${selected_names[@]}"; do
        skip=0
        for ex in "${exclude[@]}"; do [[ "$name" == "$ex" ]] && skip=1 && break; done
        [[ $skip -eq 0 ]] && filtered+=("$name")
    done
    selected_names=("${filtered[@]}")
fi

[[ ${#selected_names[@]} -gt 0 ]] || die "no skills left to install after --skills/--exclude filtering"

selected_names_sorted="$(printf '%s\n' "${selected_names[@]}" | sort)"

# --------------------------------------------------------------------------
# already-up-to-date short-circuit
# --------------------------------------------------------------------------

if [[ $force -eq 0 && -f "$lockfile_path" ]]; then
    lock_commit="$(lock_field commit)"
    if [[ "$lock_commit" == "$remote_sha" && "$(lock_skill_names)" == "$selected_names_sorted" ]]; then
        log "already up to date — nothing to clone, no skills changed"
        printf '{"scope": "%s", "repo": "%s", "ref": "%s", "commit": "%s", "upToDate": true, "installed": []}\n' \
            "$(json_escape "$scope")" "$(json_escape "$repo")" "$(json_escape "$ref")" "$remote_sha"
        exit 0
    fi
fi

# --------------------------------------------------------------------------
# install
# --------------------------------------------------------------------------

[[ $dry_run -eq 1 ]] || mkdir -p "$scope"

entries="" lock_entries="" changed_count=0
for name in "${selected_names[@]}"; do
    rel="$(rel_for "$name")"
    tree="$(git -C "$tmp_dir" rev-parse "HEAD:${rel}")"

    changed=false
    if [[ $force -eq 1 || "$(lock_tree_for "$name")" != "$tree" ]]; then
        changed=true
        changed_count=$((changed_count + 1))
    fi

    if [[ $dry_run -eq 0 ]]; then
        rm -rf "${scope:?}/${name}"
        cp -R "${tmp_dir}/${rel}" "${scope}/${name}"
    fi

    [[ -n "$entries" ]] && entries+=","
    entries+=$'\n    {"name": "'"$name"'", "tree": "'"$tree"'", "changed": '"$changed"', "path": "'"$(json_escape "${scope}/${name}")"'"}'
    [[ -n "$lock_entries" ]] && lock_entries+=","
    lock_entries+=$'\n    {"name": "'"$name"'", "tree": "'"$tree"'"}'
done
[[ -n "$entries" ]] && entries+=$'\n  '
[[ -n "$lock_entries" ]] && lock_entries+=$'\n  '

log "installed ${#selected_names[@]} skills, ${changed_count} new or changed"

if [[ $dry_run -eq 0 ]]; then
    tmp_lock="${lockfile_path}.tmp.$$"
    cat >"$tmp_lock" <<EOF
{
  "repo": "$(json_escape "$repo")",
  "ref": "$(json_escape "$ref")",
  "commit": "$commit",
  "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "skills": [${lock_entries}]
}
EOF
    mv -f "$tmp_lock" "$lockfile_path"
    log "lockfile written: $lockfile_path"
fi

drop_tmp

cat <<EOF
{
  "scope": "$(json_escape "$scope")",
  "repo": "$(json_escape "$repo")",
  "ref": "$(json_escape "$ref")",
  "commit": "$commit",
  "dryRun": $([[ $dry_run -eq 1 ]] && printf 'true' || printf 'false'),
  "upToDate": false,
  "changedCount": $changed_count,
  "installed": [${entries}]
}
EOF
