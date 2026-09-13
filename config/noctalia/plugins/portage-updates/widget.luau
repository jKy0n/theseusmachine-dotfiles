--!nonstrict
-- Bar widget que mostra quantos pacotes o Portage tem disponíveis para
-- atualização no Gentoo.
--
-- Não roda `emerge` nenhum aqui: só lê o cache que os timers systemd
-- (mirrorselect-update.timer + portage-sync-cache.timer, definidos fora
-- deste repo em /etc/jkyon-systemd) já mantêm atualizado em:
--
--   /var/cache/portage-update-checker/status.json
--   { "count": N, "updated_at": "<ISO8601>", "packages": [...] }
--
-- O mesmo arquivo já alimenta o módulo custom/portage-updates do Waybar
-- (config/waybar/config.jsonc + scripts em /etc/jkyon-systemd), então este
-- widget é só um "renderer" alternativo do mesmo dado.

local CACHE_PATH = "/var/cache/portage-update-checker/status.json"
-- Separa count/updated_at/packages por TAB, e cada pacote por uma quebra de
-- linha real (join puro, não @tsv, para o \n não ser escapado de volta em
-- texto literal "\n" no tooltip).
local JQ_FILTER = '[(.count|tostring), .updated_at, (.packages // [] | join("\\n"))] | join("\\t")'
local UPDATE_INTERVAL_MS = 5 * 60 * 1000 -- o cache só muda 1-2x/dia; 5 min já sobra

local function renderUnavailable()
  barWidget.setVisible(true) -- erro real: mostra "?" em vez de sumir silenciosamente
  barWidget.setGlyph("download")
  barWidget.setText("?")
  barWidget.setTooltip("Cache do Portage indisponível (" .. CACHE_PATH .. ")")
end

local function renderCount(count, updatedAt, packages)
  if count == "0" then
    -- Nada para atualizar: some da barra em vez de mostrar "0".
    barWidget.setVisible(false)
    return
  end

  barWidget.setVisible(true)
  barWidget.setGlyph("download")
  barWidget.setText(count)

  local tooltip = "Pacotes disponíveis: " .. count
  if updatedAt ~= nil and updatedAt ~= "" then
    tooltip = tooltip .. "\nÚltima sincronização: " .. updatedAt
  end
  if packages ~= nil and packages ~= "" then
    tooltip = tooltip .. "\n\n" .. packages
  end
  barWidget.setTooltip(tooltip)
end

local function onResult(result)
  if result == nil or result.exitCode ~= 0 or result.stdout == nil then
    renderUnavailable()
    return
  end

  local output = result.stdout:gsub("%s+$", "") -- remove newline final
  local count, updatedAt, packages = output:match("^(%d+)\t([^\t]*)\t?(.*)$")

  if count == nil then
    renderUnavailable()
    return
  end

  renderCount(count, updatedAt, packages)
end

local function refresh()
  noctalia.runAsync({ "jq", "-r", JQ_FILTER, CACHE_PATH }, onResult)
end

function update()
  noctalia.setUpdateInterval(UPDATE_INTERVAL_MS)
  refresh()
end

function onClick()
  -- Sem side-effects em `emerge`; só força reler o cache imediatamente
  -- em vez de esperar o próximo tick do polling.
  refresh()
end
