#!/usr/bin/env bash
# put the toolchain back after a fresh workspace.
# it lives in ~/.cache on purpose; the snapshot skips the cache, so the
# repo stays the only thing that persists.
set -e

export RUSTUP_HOME="$HOME/.cache/rustup"
export CARGO_HOME="$HOME/.cache/cargo"
export PATH="$CARGO_HOME/bin:$HOME/.cache/cue:$PATH"

if ! command -v cargo >/dev/null 2>&1; then
  echo "fetching rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
fi

if ! command -v elixir >/dev/null 2>&1; then
  echo "fetching elixir..."
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq elixir
fi

if [ ! -x "$HOME/.cache/cue/cue" ]; then
  echo "fetching cue..."
  mkdir -p "$HOME/.cache/cue"
  curl -sL https://github.com/cue-lang/cue/releases/download/v0.17.1/cue_v0.17.1_linux_amd64.tar.gz \
    | tar xz -C "$HOME/.cache/cue" cue
fi

echo ""
echo "toolchain ready;"
echo "  cargo  $(cargo --version 2>/dev/null || echo missing)"
echo "  elixir $(elixir --version 2>/dev/null | tail -1 || echo missing)"
echo "  cue    $("$HOME/.cache/cue/cue" version 2>/dev/null | head -1 || echo missing)"
echo ""
echo "in shells that need it; export RUSTUP_HOME=$RUSTUP_HOME CARGO_HOME=$CARGO_HOME"
