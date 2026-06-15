#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Sphinx (RST) -> Jekyll just-the-docs (Markdown) doc migration.
#
# CONTEXT
# -------
# Migrates the NWebsec.SessionSecurity docs off a legacy Sphinx/readthedocs
# setup onto a Jekyll + just-the-docs GitHub Pages site. This is the same recipe
# used for the main NWebsec docs (NWebsec/Docs); it was lifted and adapted here.
# Adapt the per-file mapping near the bottom (titles / nav_order / parent) and
# the SRC/ROOT/OUT paths below for each repo; the conversion + cleanup machinery
# is generic.
#
# DIFFERENCE FROM THE NWEBSEC/Docs REPO: there, the RST lived under
# `source/nwebsec/`, so the converted pages keep a `/nwebsec/` URL segment. In
# THIS repo the RST sits directly under `source/`, so the old readthedocs URLs
# had no sub-folder. We therefore convert FLAT into `docs/en/latest/` (ROOT ==
# OUT) to keep `/en/latest/<x>.html` working.
#
# The whole approach (decided with the repo owner):
#   - Theme: just-the-docs (a *gem* theme, NOT in GitHub Pages' built-in theme
#     allowlist -- this matters for deploy, see DEPLOY below).
#   - Conversion: batch with pandoc (rst -> gfm), then fix the rough edges here,
#     then a human reviews the Markdown.
#   - Versioning: only /en/latest/ for now, to preserve old readthedocs URLs.
#   - Keep the original source/ RST on the `master` branch after conversion.
#
# URL layout mirrors the old readthedocs paths so existing links keep working.
# The home page (Sphinx master_doc, index.rst) and every other page sit at the
# version root:
#   source/index.rst   -> docs/en/latest/index.md   (/en/latest/)
#   source/<x>.rst      -> docs/en/latest/<x>.md      (/en/latest/<x>.html)
#
# NAV / FRONT MATTER (just-the-docs specifics)
#   - Top-level nav_order follows the master index.rst toctree order.
#   - A page with children needs `has_children: true`; each child needs
#     `parent: "<exact title of the parent page>"` (matched by title, not path,
#     so moving files between folders does NOT break the parent/child nav).
#   - Cross-page links are kept as bare relative `<Name>.html` so they survive
#     pages living together in the same folder.
#
# PANDOC ROUGH EDGES handled in the cleanup pass below (watch for these again):
#   - `:doc:` cross-refs: rewritten in the RST *before* pandoc (to RST link
#     form) so they become real links instead of inline code spans.
#   - An EMPTY `:doc:``` ref (a half-finished sentence in index.rst) is stripped
#     so it doesn't survive as a stray empty code span. (Owner chose to keep the
#     surrounding sentence and only fix the broken markup.)
#   - Code fences: Sphinx default highlight is csharp (conf.py highlight_language
#     = 'csharp'); pandoc emits "``` c#" -- normalised to "```csharp". Other
#     explicit langs (powershell, html, xml) are kept, just de-spaced.
#   - `.. toctree::` blocks render as a raw <div class="toctree"> dump -- removed
#     (nav comes from front matter instead).
#   - `.. <default-role>` single-backtick text -> <span class="title-ref"> -> *em*.
#   - GOTCHA: `perl -0pi` (slurp/in-place) SILENTLY NO-OPS under git-bash when
#     run from a script, so the multi-line toctree <div> is stripped with awk
#     instead. Line-mode `perl -pi` is fine. Don't "simplify" the awk back to
#     perl -0pi without testing on Windows/git-bash.
#
# TOOLCHAIN: needs ruby, bundle, jekyll, pandoc on PATH. On Ruby 3+, `jekyll
# serve` also needs the `webrick` gem in the Gemfile.
#
# DEPLOY: just-the-docs is a gem theme, so GitHub Pages' classic "Deploy from a
# branch" build renders it UNSTYLED. Build it yourself in a GitHub Actions
# workflow with ruby/setup-ruby + `bundle exec jekyll build` (NOT
# actions/jekyll-build-pages, which uses the preinstalled github-pages gem env).
# This site is a GitHub *project* site (no custom domain), served at
# https://nwebsec.github.io/Docs.SessionSecurity/, so it is built WITH
# `--baseurl "/Docs.SessionSecurity"` (set in _config.yml and the workflow).
# Commit Gemfile.lock and add the CI platform:
# `bundle lock --add-platform x86_64-linux`. Gitignore _site/ and
# .jekyll-cache/. Set the Pages source to GitHub Actions in Settings > Pages.
# =============================================================================

SRC="source"                   # RST lives directly under source/ in this repo
ROOT="docs/en/latest"          # home (index) lives here
OUT="docs/en/latest"           # everything else too -- flat layout
mkdir -p "$ROOT" "$OUT"

# Front matter writer.
# args: outfile, title, nav_order, [parent], [has_children]
emit_fm() {
  local file="$1" title="$2" order="$3" parent="${4:-}" haschildren="${5:-}"
  {
    echo "---"
    echo "title: \"$title\""
    echo "nav_order: $order"
    [ -n "$parent" ] && echo "parent: \"$parent\""
    [ -n "$haschildren" ] && echo "has_children: true"
    echo "---"
    echo ""
  } > "$file.fm"
}

# Convert one rst -> md body (no front matter yet).
convert() {
  local in="$1" out="$2"
  local tmp="/tmp/pp_$(basename "$in")"
  # Rewrite :doc:`Target` -> `Target <Target.html>`_ (RST link form) so pandoc makes a real link,
  # then drop any empty :doc:`` ref (broken half-finished sentence) entirely.
  sed -E -e 's/:doc:`([^`<]+)`/`\1 <\1.html>`_/g' -e 's/:doc:``//g' "$in" > "$tmp"
  pandoc -f rst -t gfm --wrap=none "$tmp" -o "$out.body"
}

# Combine front matter + body.
assemble() {
  local out="$1"
  cat "$out.fm" "$out.body" > "$out"
  rm -f "$out.fm" "$out.body"
}

# ---- home (index) ----
convert "$SRC/index.rst" "$ROOT/index.md"
emit_fm "$ROOT/index.md" "Home" 1
assemble "$ROOT/index.md"

# ---- top-level pages (toctree order) ----
convert "$SRC/Configuring-session-security.rst" "$OUT/Configuring-session-security.md"
emit_fm "$OUT/Configuring-session-security.md" "Configuring session security" 2
assemble "$OUT/Configuring-session-security.md"

convert "$SRC/Authenticated-session-identifiers.rst" "$OUT/Authenticated-session-identifiers.md"
emit_fm "$OUT/Authenticated-session-identifiers.md" "Authenticated session identifiers" 3 "" "yes"
assemble "$OUT/Authenticated-session-identifiers.md"

# ---- children of "Authenticated session identifiers" ----
ASIPARENT="Authenticated session identifiers"
convert "$SRC/AuthenticatedSessionIDManager.rst" "$OUT/AuthenticatedSessionIDManager.md"
emit_fm "$OUT/AuthenticatedSessionIDManager.md" "AuthenticatedSessionIDManager" 1 "$ASIPARENT"
assemble "$OUT/AuthenticatedSessionIDManager.md"

# ---- final cleanup pass over every generated page ----
# Note: perl -0pi (slurp mode) silently no-ops under bash/git-bash here, so the
# multi-line toctree block is stripped with awk instead.
for f in "$OUT"/*.md; do
  # strip pandoc's rendered ".. toctree::" blocks (nav comes from front matter instead)
  awk '/<div class="toctree"/{skip=1} skip && /<\/div>/{skip=0; next} !skip' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  # default highlight language is csharp; normalise fence info strings
  sed -E -i -e 's/^``` c#/```csharp/' -e 's/^``` (.*)$/```\1/' "$f"
  # title-reference roles -> emphasis (handles escaped <> inside)
  perl -pi -e 's/<span class="title-ref">(.*?)<\/span>/*$1*/g' "$f"
done

echo "Done."
echo "Home:  $ROOT/index.md"
echo "Pages: $OUT"
ls -1 "$OUT"
