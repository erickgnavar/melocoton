#! /bin/bash
# make sure we have available all the tools are installed by mise
eval "$(mise activate bash)"

# install elixir dependencies
mix deps.get

# clean up previous builds
rm -fr _build/prod 2 &>/dev/null
rm -fr burrito_out 2 &>/dev/null

# install assets nodejs dependencies
npm install --prefix assets

# compile assets
MIX_ENV=prod mix assets.deploy

# compile sidebar elixir application
BURRITO_TARGET=macos MIX_ENV=prod mix release || exit 1

cp ./burrito_out/melocoton_macos ./src-tauri/binaries/webserver

cd src-tauri || exit 1

# install tauri dependencies
npm install

# build dmg
npm run tauri build
