#! /bin/bash

mkdir -p src-tauri/binaries

cd webapp/ || exit 1

rm -fr _build/prod 2 &>/dev/null
rm -fr burrito_out 2 &>/dev/null

BURRITO_TARGET=macos MIX_ENV=prod mix release

cp ./burrito_out/melocoton_macos ../src-tauri/binaries/webserver

cd ..

cd src-tauri || exit 1

npm run tauri build
