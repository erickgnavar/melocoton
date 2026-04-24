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

# set up compilation target
OS_NAME=$(uname -o)
ARCH=$(uname -m)
echo "Running on $OS_NAME ($ARCH)..."

if [[ "$OS_NAME" == "Darwin" ]]; then
  export BURRITO_TARGET=macos
elif [[ "$OS_NAME" == "GNU/Linux" ]]; then
  # Burrito ships a musl-linked ERTS on Linux, so we need rustler_precompiled
  # NIFs (mdex/lumis) to target musl too, otherwise dlopen fails at runtime.
  export TARGET_ABI=musl
  export TARGET_OS=linux
  export TARGET_ARCH="$ARCH"

  if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    export BURRITO_TARGET=linux_arm
  else
    export BURRITO_TARGET=linux
  fi
else
  echo "Unsupported platform"
  echo "Use build.ps1 for Windows builds."
  exit 1
fi

# compile sidebar elixir application
MIX_ENV=prod mix release || exit 1

if [[ "$OS_NAME" == "Darwin" ]]; then
  cp ./burrito_out/melocoton_macos ./src-tauri/binaries/webserver
elif [[ "$OS_NAME" == "GNU/Linux" ]]; then
  if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    cp ./burrito_out/melocoton_linux_arm ./src-tauri/binaries/webserver
  else
    cp ./burrito_out/melocoton_linux ./src-tauri/binaries/webserver
  fi
else
  echo "Unsupported platform"
  echo "Use build.ps1 for Windows builds."
  exit 1
fi

cd src-tauri || exit 1

# install tauri dependencies
npm install

# build dmg
npm run tauri build
