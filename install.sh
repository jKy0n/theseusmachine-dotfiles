#!/usr/bin/env bash
# ~/.dotfiles/install.sh
# Aplica todos os pacotes stow. Idempotente — seguro rodar mais de uma vez,
# inclusive numa máquina já migrada (vira no-op silencioso).

set -euo pipefail

DOTFILES="$HOME/.dotfiles/config"
TARGET_BASE="$HOME/.config"

# pacotes padrão: destino é sempre $TARGET_BASE/<pkg>
PACKAGES=(atuin fastfetch modprobed-db niri satty xdg-desktop-portal)

echo "==> Aplicando stow"
for pkg in "${PACKAGES[@]}"; do
  mkdir -p "$TARGET_BASE/$pkg"
  echo "  -> $pkg"
  stow -v -d "$DOTFILES" -t "$TARGET_BASE/$pkg" "$pkg"
done

# GTK 3/4 e Qt não têm pacote aqui: o Noctalia gera gtk.css/noctalia.css e
# qt5ct/qt6ct colors a partir de [theme.templates] em config/noctalia/config.toml.
# O settings.ini (base adw-gtk3-dark) fica direto em ~/.config.

# modprobed-db não lê ~/.config/modprobed-db/modprobed-db.conf (aninhado) —
# só o caminho plano ~/.config/modprobed-db.conf. Companion symlink manual,
# fora do escopo do stow.
ln -sfv "$DOTFILES/modprobed-db/modprobed-db.conf" "$TARGET_BASE/modprobed-db.conf"

# Noctalia v5 lê duas camadas, nesta ordem:
#   1. ~/.config/noctalia/*.toml              → config do usuário (versionado aqui)
#   2. ~/.local/state/noctalia/settings.toml  → fallback da GUI (local, NÃO versionar)
# config.toml é mínimo: só o que difere do padrão. O settings.toml deve ficar só com
# config_version + [location] (privado). Mudou algo pela GUI e quer manter?
# `noctalia config export merged`, traga o trecho pro config.toml e limpe o settings.toml.
# Symlink só do arquivo (não stow do pacote) pra plugins/ não ir parar em ~/.config/noctalia.
mkdir -p "$TARGET_BASE/noctalia"
ln -sfv "$DOTFILES/noctalia/config.toml" "$TARGET_BASE/noctalia/config.toml"

echo "==> Concluído"