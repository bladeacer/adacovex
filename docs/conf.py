# Sphinx configuration for the adacovex manual.
#
# The manual source is the Markdown project at `docs/` (Read the Docs builds
# it -- see .readthedocs.yaml `sphinx.configuration: docs/conf.py`).  The
# same docs compile into the bundled offline manual that the --serve server
# exposes at /docs (tools/gen-docs.py runs this very sphinx-build and embeds
# the output).  The pages stay Markdown: the MyST parser reads `docs/*.md`
# unchanged, so no page is ever converted to reStructuredText.
#
# Only the Toolchain requires Python.  The adacovex binary itself has no
# Python or docs dependency; sphinx + myst-parser are dev/toolchain
# dependencies (docs/../requirements.txt) used by `tools/gen-docs.py`, the
# `make book` / `book-links-check` targets, and Read the Docs.
#
# The built-in default theme (alabaster) is used -- no third-party theme, so
# the build works offline with nothing more than sphinx + myst-parser.

import os

# -- Project -----------------------------------------------------------------

project = "adacovex"
author = "bladeacer"
copyright = "bladeacer"
release = "latest"

# -- General -----------------------------------------------------------------

# The manual index lives at docs/index.md (the landing page).  `root_doc`
# names the master document that hosts the toctree.
root_doc = "index"
source_suffix = {".md": "markdown"}

# MyST turns the .md pages into Sphinx documents without reStructuredText.
extensions = ["myst_parser"]

# Every heading gets a stable "#slug" anchor at depth 3 (matching the
# maximum heading depth the pages use), so section links stay permanent.
myst_heading_anchors = 3

# Build products and generated (per-release) sub-trees are never sources.
# SUMMARY.md and book.toml are the retired mdBook TOC/config; they are kept
# as historical artifacts but must not build.
exclude_patterns = [
    "SUMMARY.md",
    "book.toml",
    "_build",
    "**/*.orig.md",
]

# The api-docs/, changelogs/, proof/, compliance/ and badges/ pages are
# reached through their section index pages (and search), not the top-level
# sidebar.  Sphinx warns for every page not named in a toctree; those are
# expected here, so the warning is silenced -- every such page still builds,
# is reachable via its index and the built-in search, and is bundled into
# the offline manual.
suppress_warnings = ["toc.not_included"]

# -- HTML output (default theme) ---------------------------------------------

# The built-in default theme (alabaster).  No extra dependency.
html_theme = "alabaster"

# Canonical URL for Read the Docs (no effect on the local/offline build).
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "/")

# The offline manual must build purely from source with no network: the
# default theme pulls no fonts or images, so nothing else needs bundling.