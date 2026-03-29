os := if os() == "macos" { "macos" } else { "linux" }
burrito_bin := if os == "macos" { "melocoton_macos" } else { "melocoton_linux" }

# Development
dev:
    iex -S mix phx.server

test:
    mix test

fmt:
    mix format --migrate

ci:
    mix ci

setup:
    mix setup

deps:
    mix deps.get
    npm install --prefix assets

# Release — full desktop app build
release: clean-release deps assets sidecar tauri

# Individual release steps
clean-release:
    rm -rf _build/prod burrito_out

assets:
    MIX_ENV=prod mix assets.deploy

sidecar:
    BURRITO_TARGET={{ os }} MIX_ENV=prod mix release
    cp ./burrito_out/{{ burrito_bin }} ./src-tauri/binaries/webserver

tauri:
    cd src-tauri && npm install && npm run tauri build

# Development build (Tauri dev mode with hot reload)
tauri-dev:
    cd src-tauri && npm run tauri dev

# Database
db-migrate:
    mix ecto.migrate

db-reset:
    mix ecto.reset

mysql:
    docker run --rm --name melocoton-mysql --network host -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=melocoton_dev mysql:8

version:
    @grep '"version"' src-tauri/tauri.conf.json | head -1 | sed 's/.*"\([0-9.]*\)".*/\1/'

bump-version version:
    sed -i'' -e 's/"version": "[0-9.]*"/"version": "{{ version }}"/' src-tauri/tauri.conf.json
    sed -i'' -e 's/"version": "[0-9.]*"/"version": "{{ version }}"/' package.json
    sed -i'' -e '3s/"version": "[0-9.]*"/"version": "{{ version }}"/' package-lock.json
    sed -i'' -e 's/^version = "[0-9.]*"/version = "{{ version }}"/' src-tauri/Cargo.toml
    sed -i'' -e 's/version: "[0-9.]*"/version: "{{ version }}"/' mix.exs
    git add src-tauri/tauri.conf.json src-tauri/Cargo.toml package.json package-lock.json mix.exs
    git commit -m "chore: bump v{{ version }}"
    git tag -a "v{{ version }}" -m "v{{ version }}"
