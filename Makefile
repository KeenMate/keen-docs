.PHONY: help deps dev iex kill-port db-gen demo poc test clean vendor-css

# Pick the right db-gen binary for the platform (Windows .exe vs linux).
DBGEN := $(if $(findstring Windows_NT,$(OS)),./db-gen-win.exe,./db-gen-linux)

# Pinned @keenmate/pure-css release the vendored CSS tracks. Bump + `make vendor-css` to update.
PURE_CSS_VERSION := 1.0.0-rc01

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
	@echo "  vendor-css Re-vendor @keenmate/pure-css@$(PURE_CSS_VERSION) CSS from npm"
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
	-@netstat -ano | grep -E ':$(PORT)[^0-9]' | grep LISTENING | awk '{print $$5}' | sort -u | while read pid; do MSYS_NO_PATHCONV=1 taskkill /F /PID $$pid; done
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

# Re-vendor the pure-css foundation CSS from the PINNED published release (the registry is the
# single source of truth — avoids drift like a stale local-copy grid). `npm pack` needs no
# package.json here; it just downloads + extracts the tarball into a temp dir.
vendor-css:
	@echo "Vendoring @keenmate/pure-css@$(PURE_CSS_VERSION) from npm..."
	@dest="$$PWD/priv/web/vendor/pure-css"; tmp=`mktemp -d`; \
	( cd "$$tmp" && npm pack @keenmate/pure-css@$(PURE_CSS_VERSION) >/dev/null && tar -xzf *.tgz ); \
	for f in base grid utilities; do cp "$$tmp/package/dist/css/$$f.css" "$$dest/$$f.css"; done; \
	rm -rf "$$tmp"; \
	echo "Vendored base/grid/utilities.css -> priv/web/vendor/pure-css (rebuild to re-inline base.css)"

test:
	mix test

clean:
	rm -rf build _build
