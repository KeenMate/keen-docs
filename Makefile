.PHONY: help deps dev iex kill-port db-gen demo poc test clean vendor-css vendor-css-npm vendor-pa-core seed-themes

# Pick the right db-gen binary for the platform (Windows .exe vs linux).
DBGEN := $(if $(findstring Windows_NT,$(OS)),./db-gen-win.exe,./db-gen-linux)

# Pinned @keenmate/pure-css release the vendored CSS tracks. Bump + `make vendor-css` to update.
PURE_CSS_VERSION := 1.0.0-rc04

# The Bandit HTTP port (keep in sync with config :keen_docs, KeenDocs.Web, port:).
PORT := 4000

# Show available targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Run:"
	@echo "  dev       Start the web test harness (Bandit on :$(PORT))"
	@echo "  iex       Start an IEx session with the app running"
	@echo "  kill-port Free port $(PORT) (stale harness)"
	@echo "  demo      Print the read-only content visualizer (nav / URLs / resolution)"
	@echo "  poc       Build the standalone markdown POC -> build/poc.html"
	@echo ""
	@echo "Codegen / deps:"
	@echo "  deps       Fetch mix dependencies"
	@echo "  db-gen     Regenerate the DB wrappers from the live keen_docs DB"
	@echo "  vendor-css Re-vendor @keenmate/pure-css CSS from the local ../pure-css build (latest)"
	@echo "  vendor-css-npm  Re-vendor from the pinned npm release @$(PURE_CSS_VERSION)"
	@echo "  vendor-pa-core  Re-vendor the pure-admin core.css framework bundle (the baseline shell)"
	@echo "  seed-themes  Install the keendocs.json theme bundles from ../pure-admin-themes"
	@echo "  test       Run the test suite"
	@echo "  clean      Remove build artifacts"

# Fetch dependencies
deps:
	mix deps.get

# Start the web test harness (http://localhost:4000). Frees the port first so a stale
# harness doesn't cause "address in use".
dev: kill-port
	mix run --no-halt

# Interactive session with the supervision tree running
iex: kill-port
	iex -S mix

# Free the Bandit port. Kills whatever is LISTENING on it, covering IPv4 and IPv6.
# Recipes default to Git Bash (sh); on Windows we call netstat/taskkill directly.
kill-port: ## Free port $(PORT) (stale harness)
	@echo "Freeing port $(PORT)..."
ifeq ($(OS),Windows_NT)
	-@netstat -ano | grep -E ':$(PORT)[^0-9]' | grep LISTENING | awk '!seen[$$5]++ {print $$5}' | while read pid; do MSYS_NO_PATHCONV=1 taskkill /F /PID $$pid; done
else
	-@lsof -ti tcp:$(PORT) | xargs -r kill -9
endif
	@echo "Port $(PORT) is free"

# Regenerate KeenDocs.Database.* from the live DB (needs VPN to db-01.km8.local).
# Wipe first so removed routines don't leave orphaned wrappers.
db-gen:
	rm -rf lib/keen_docs/database
	$(DBGEN) generate

# Read-only visualizer over the seeded content
demo:
	mix run tmp/docs_variant_demo.exs

# Standalone markdown POC page
poc:
	mix run -e "KeenDocs.POC.build()"

# The set of CSS layers vendored from pure-css (base.css inlined; the rest served/linked).
PURE_CSS_FILES := base grid utilities reboot scrollbars
# Local pure-css working copy (sibling repo) — the source while co-developing both.
PURE_CSS_DIR := ../pure-css
# Local pure-admin working copy — source for the core framework bundle (the keen-docs baseline).
PURE_ADMIN_DIR := ../pure-admin

# Re-vendor the pure-css foundation CSS from the LOCAL sibling working copy (co-development: pick up
# the latest build immediately, no publish/version bump needed). Assumes ../pure-css is freshly BUILT
# (run its `make`/build first) — vendoring a stale dist once left an old grid behind. For a pinned,
# registry-as-truth build instead, use `make vendor-css-npm`.
vendor-css:
	@echo "Vendoring @keenmate/pure-css from $(PURE_CSS_DIR)/dist/css (local working copy)..."
	@dest="$$PWD/priv/web/vendor/pure-css"; src="$(PURE_CSS_DIR)/dist/css"; \
	for f in $(PURE_CSS_FILES); do cp "$$src/$$f.css" "$$dest/$$f.css"; done; \
	echo "Vendored $(PURE_CSS_FILES) .css -> priv/web/vendor/pure-css (rebuild to re-inline base.css)"

# Re-vendor from the PINNED published npm release (registry as single source of truth). `npm pack`
# needs no package.json; it downloads + extracts the tarball into a temp dir. Note: layers added
# after the pinned version (e.g. reboot/scrollbars in rc02) won't exist until that version ships.
vendor-css-npm:
	@echo "Vendoring @keenmate/pure-css@$(PURE_CSS_VERSION) from npm..."
	@dest="$$PWD/priv/web/vendor/pure-css"; tmp=`mktemp -d`; \
	( cd "$$tmp" && npm pack @keenmate/pure-css@$(PURE_CSS_VERSION) >/dev/null && tar -xzf *.tgz ); \
	for f in $(PURE_CSS_FILES); do [ -f "$$tmp/package/dist/css/$$f.css" ] && cp "$$tmp/package/dist/css/$$f.css" "$$dest/$$f.css" || echo "  (skip $$f.css — not in $(PURE_CSS_VERSION))"; done; \
	rm -rf "$$tmp"; \
	echo "Vendored -> priv/web/vendor/pure-css (rebuild to re-inline base.css)"

# Re-vendor the pure-admin CORE framework bundle — the keen-docs baseline shell (10px rem base +
# reset + grid + utilities + all pa-* chrome + a baked light palette). This ONE self-contained sheet
# is linked by View.styles/1 when no template is active, replacing the old hand-extracted fragments.
# Assumes ../pure-admin core is freshly BUILT. Real themes (Phase 2) will supersede it per doc_set.
vendor-pa-core:
	@echo "Vendoring pure-admin core.css from $(PURE_ADMIN_DIR)/packages/core/dist/css/main.css..."
	@cp "$(PURE_ADMIN_DIR)/packages/core/dist/css/main.css" "$$PWD/priv/web/vendor/pure-admin/core.css"
	@cp "$(PURE_ADMIN_DIR)/packages/core/src/js/navbar-collapse.js" "$$PWD/priv/web/vendor/pure-admin/navbar-collapse.js"
	@cp "$(PURE_ADMIN_DIR)/demo/js/sidebar-resize.js" "$$PWD/priv/web/vendor/pure-admin/sidebar-resize.js"
	@echo "Vendored -> priv/web/vendor/pure-admin/{core.css,navbar-collapse.js,sidebar-resize.js}"

# Install the theme bundles declared in keendocs.json by copying them from ../pure-admin-themes
# (theme.json + dist/<id>.css + assets/) into themesDir, and write keendocs.lock.json. The manual
# stand-in for the future `keendocs themes install` (themes Phase 4). Re-run after editing
# keendocs.json's theme list or rebuilding the theme sources.
seed-themes:
	@echo "Seeding themes from $$(sed -n 's/.*\"source\": *\"\([^\"]*\)\".*/\1/p' keendocs.json)..."
	@mix run --no-start -e 'KeenDocs.Themes.seed_from()'

test:
	mix test

clean:
	rm -rf build _build
