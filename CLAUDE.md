# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The documentation site for **NWebsec.SessionSecurity** (a library that improves ASP.NET session security by binding an authenticated user's identity to their session identifier), published as a GitHub **project** site at **https://nwebsec.github.io/Docs.SessionSecurity/**. The docs were migrated from a legacy Sphinx/readthedocs (RST) setup to **Jekyll 4.4 + the just-the-docs gem theme** on GitHub Pages, mirroring the setup of the main NWebsec docs (NWebsec/Docs).

## Branch layout (important)

The two branches hold different generations of the docs — they are not a normal feature/main split:

- **`master`** — the original Sphinx source: `source/*.rst`, `Makefile`, `make.bat`. This is the *input* to the migration.
- **`gh-pages`** — the converted Jekyll site (`docs/`), the migration script (`convert.sh`), and the deploy workflow. This is the branch the site is built from. **This is the default working branch for doc work.**

`convert.sh` reads from `source/` (which lives on `master`), so running the full conversion requires both generations present (e.g. run it where the `master` `source/` tree is checked out alongside the `gh-pages` `docs/` output).

## The Jekyll site (`docs/`)

- `docs/_config.yml` — site config. **`baseurl` must stay `"/Docs.SessionSecurity"`**: this is a GitHub *project* site (no custom domain), so every link/asset is prefixed with the repo path. (This is the one real difference from NWebsec/Docs, which serves at a custom-domain apex with an empty baseurl.)
- `docs/index.html` — meta-refresh redirect from the site root to `/Docs.SessionSecurity/en/latest/` (preserves old readthedocs URLs).
- `docs/en/latest/index.md` — home page. `docs/en/latest/*.md` — all other pages, **flat** in the same folder (the RST lived directly under `source/`, not a sub-folder, so the old readthedocs URLs had no sub-path segment).
- Navigation comes from just-the-docs **front matter** (`title`, `nav_order`, `parent`, `has_children`), not from a toctree. `parent` is matched by the parent page's exact `title`, not by path — so files can move between folders without breaking nav.
- `docs/Gemfile.lock` is committed on purpose (reproducible CI). Both the local Windows platform and `x86_64-linux` (CI) are locked.

### Local development

```bash
cd docs
bundle install
bundle exec jekyll serve    # http://127.0.0.1:4000/Docs.SessionSecurity/
```

Requires Ruby 3.x, bundler. `webrick` is in the Gemfile because Ruby 3+ no longer bundles it (needed by `jekyll serve`).

## Deployment

`.github/workflows/jekyll-gh-pages.yml` builds and deploys to GitHub Pages on push to `gh-pages` (paths `docs/**` or the workflow itself), or manually.

Two deliberate, non-obvious choices — do **not** "fix" these without understanding why:

- **Do not use `actions/jekyll-build-pages`.** It builds in GitHub's preinstalled `github-pages` gem environment (Jekyll 3.9, built-in theme allowlist), which excludes just-the-docs and renders the site unstyled. The workflow uses `ruby/setup-ruby` + `bundle exec jekyll build` instead, so the exact verified gems are used.
- **Build with `--baseurl "/Docs.SessionSecurity"`, not `steps.pages.outputs.base_path`.** It is passed explicitly (matching `_config.yml`) to keep the build deterministic.

The workflow currently triggers from `gh-pages`; the comment notes it should switch to `master` later. In the repo's **Settings > Pages**, set the source to **GitHub Actions**.

## The migration script (`convert.sh`)

`convert.sh` batch-converts the RST to just-the-docs Markdown (pandoc `rst -> gfm`, then a cleanup pass). It is the same recipe used for NWebsec/Docs, adapted here. The header comment documents the full rationale and the pandoc rough edges it fixes. When adapting it for another repo: change the `SRC`/`ROOT`/`OUT` paths and the per-file mapping block near the bottom (title / nav_order / parent); the conversion + cleanup machinery is generic.

Notable local specifics:

- **Flat layout.** The RST sits directly under `source/` (not a sub-folder), so `ROOT == OUT == docs/en/latest` and every page converts into that one folder.
- **Empty `:doc:` ref.** `source/index.rst` has a half-finished sentence with an empty `:doc:``` cross-reference; the script strips just that broken markup (the owner chose to keep the surrounding sentence).
- **Windows/git-bash gotcha** (already handled): `perl -0pi` (slurp/in-place) silently no-ops under git-bash when run from a script — the multi-line toctree `<div>` is stripped with `awk` instead. Line-mode `perl -pi` is fine. Don't convert the awk back to `perl -0pi` without testing on git-bash.

Requires `pandoc` on PATH (plus ruby/bundle/jekyll for previewing the result).
