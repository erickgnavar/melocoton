#! /bin/bash

mix deps.get

rm -fr _build/prod 2 &>/dev/null
rm -fr burrito_out 2 &>/dev/null

npm install --prefix assets

MIX_ENV=prod mix assets.deploy

BURRITO_TARGET=macos MIX_ENV=prod mix release

cp ./burrito_out/melocoton_macos ./src-tauri/binaries/webserver

cd src-tauri || exit 1

npm install

npm run tauri build
