#!/usr/bin/env bash
# help.sh — Affiche et recherche dans la documentation kiss-claw (docs/help/fr/)
# Usage: help.sh [section|page|search <terms>|list]

set -euo pipefail

# Determine project root
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  ROOT="$CLAUDE_PLUGIN_ROOT"
else
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

DOC_DIR="$ROOT/docs/help/fr"
SECTIONS=("tutorials" "how-to" "reference" "explanation")

# --- Helpers ---

die() {
  echo "Erreur: $1" >&2
  exit 1
}

show_usage() {
  cat <<'USAGE'
Usage: help.sh [commande]

Commandes:
  (sans argument)           Affiche l'index principal
  tutorials                 Affiche l'index des tutoriels
  how-to                    Affiche l'index des guides pratiques
  reference                 Affiche l'index des references
  explanation               Affiche l'index des explications
  <nom-page>                Recherche et affiche une page par nom (ex: store-sh, architecture)
  search <termes>           Recherche dans toute la documentation
  list                      Liste tous les fichiers de documentation disponibles

Exemples:
  help.sh                   # Index principal
  help.sh reference         # Index reference
  help.sh store-sh          # Page reference/store-sh.md
  help.sh search session    # Recherche "session" dans la doc
  help.sh list              # Liste toutes les pages
USAGE
}

is_section() {
  local name="$1"
  for s in "${SECTIONS[@]}"; do
    [[ "$s" == "$name" ]] && return 0
  done
  return 1
}

# --- Commands ---

cmd_index() {
  local file="$DOC_DIR/index.md"
  [[ -f "$file" ]] || die "Index principal introuvable: $file"
  cat "$file"
}

cmd_section() {
  local section="$1"
  local file="$DOC_DIR/$section/index.md"
  [[ -f "$file" ]] || die "Index de section introuvable: $file"
  cat "$file"
}

cmd_page() {
  local name="$1"
  # Search for the file across all subdirectories
  local found
  found=$(find "$DOC_DIR" -name "${name}.md" -not -name "index.md" 2>/dev/null | head -1)

  if [[ -z "$found" ]]; then
    # Try with .md already stripped or partial match
    found=$(find "$DOC_DIR" -name "*${name}*.md" -not -name "index.md" 2>/dev/null | head -1)
  fi

  if [[ -z "$found" ]]; then
    die "Page non trouvee: '$name'. Utilisez 'help.sh list' pour voir les pages disponibles."
  fi

  echo "--- ${found#$DOC_DIR/} ---"
  echo ""
  cat "$found"
}

cmd_search() {
  local terms="$*"
  [[ -n "$terms" ]] || die "Veuillez fournir des termes de recherche. Usage: help.sh search <termes>"

  echo "Recherche de '$terms' dans la documentation..."
  echo ""

  local results
  results=$(grep -rn -i -F "$terms" "$DOC_DIR" --include="*.md" 2>/dev/null || true)

  if [[ -z "$results" ]]; then
    echo "Aucun resultat pour '$terms'."
    return 0
  fi

  # Format: replace full path with relative path
  echo "$results" | sed "s|${DOC_DIR}/||g"
}

cmd_list() {
  echo "Documentation kiss-claw disponible:"
  echo ""

  for section in "${SECTIONS[@]}"; do
    local section_dir="$DOC_DIR/$section"
    [[ -d "$section_dir" ]] || continue

    echo "## $section"
    find "$section_dir" -name "*.md" -not -name "index.md" | sort | while read -r file; do
      local basename
      basename=$(basename "$file" .md)
      local relpath="${file#$DOC_DIR/}"
      # Extract first heading as title
      local title
      title=$(head -5 "$file" | grep -m1 '^# ' | sed 's/^# //' || echo "$basename")
      [[ -z "$title" ]] && title="$basename"
      echo "  - $basename ($relpath) -- $title"
    done
    echo ""
  done
}

# --- Main ---

if [[ $# -eq 0 ]]; then
  cmd_index
  exit 0
fi

case "$1" in
  -h|--help|help)
    show_usage
    ;;
  search)
    shift
    cmd_search "$@"
    ;;
  list)
    cmd_list
    ;;
  *)
    if is_section "$1"; then
      cmd_section "$1"
    else
      cmd_page "$1"
    fi
    ;;
esac
