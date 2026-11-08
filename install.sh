#!/usr/bin/env bash
# ~/.dotfiles/install.sh
# Aplica todos os pacotes stow. Idempotente — seguro rodar mais de uma vez,
# inclusive numa máquina já migrada (vira no-op silencioso).

set -euo pipefail

DOTFILES="$HOME/.dotfiles/config"
TARGET_BASE="$HOME/.config"

# pacotes padrão: destino é sempre $TARGET_BASE/<pkg>
PACKAGES=(atuin fastfetch modprobed-db niri satty spotify-player xdg-desktop-portal)

echo "==> Aplicando stow"
for pkg in "${PACKAGES[@]}"; do
  mkdir -p "$TARGET_BASE/$pkg"
  echo "  -> $pkg"
  stow -v -d "$DOTFILES" -t "$TARGET_BASE/$pkg" "$pkg"
done

# gtk é exceção documentada: o pacote já contém gtk-3.0/ e gtk-4.0/
# internamente, então o destino é a raiz do ~/.config, não uma subpasta.
echo "  -> gtk (destino: ~/.config)"
stow -v -d "$DOTFILES" -t "$TARGET_BASE" gtk

# modprobed-db não lê ~/.config/modprobed-db/modprobed-db.conf (aninhado) —
# só o caminho plano ~/.config/modprobed-db.conf. Companion symlink manual,
# fora do escopo do stow.
ln -sfv "$DOTFILES/modprobed-db/modprobed-db.conf" "$TARGET_BASE/modprobed-db.conf"

# Noctalia v5 lê duas camadas, nesta ordem:
#   1. ~/.config/noctalia/*.toml              → config do usuário (versionado aqui)
#   2. ~/.local/state/noctalia/settings.toml  → overrides gravados pela GUI (estado local, NÃO versionar)
# config.toml é mínimo: só o que difere do padrão. Mudou algo pela GUI e quer manter?
# `noctalia config export merged` e copie o trecho para config/noctalia/config.toml.
# Symlink só do arquivo (não stow do pacote) pra plugins/ não ir parar em ~/.config/noctalia.
mkdir -p "$TARGET_BASE/noctalia"
ln -sfv "$DOTFILES/noctalia/config.toml" "$TARGET_BASE/noctalia/config.toml"

echo "==> Concluído"