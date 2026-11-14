--!nonstrict
-- Serviço sem widget: notificação crítica quando o hardware passa do limite.
--
-- Não coleta nada por conta própria: lê o que o system monitor do Noctalia
-- já mede ([system.monitor], CPU/RAM a cada 2 s, GPU a cada 5 s) via
-- noctalia.systemStats(). Sem processo, sem arquivo, sem unit systemd.
--
-- Anti-spam (a 5950X passa de 85 °C compilando pro distcc):
--   - só avisa depois de `sustain_samples` leituras seguidas acima do limite;
--   - avisa uma vez por episódio e só rearma quando o valor cai
--     `hysteresis` unidades abaixo do limite.

local POLL_MS = 2000
local BYTES_PER_MIB = 1024 * 1024

local function number(value, fallback)
  local n = tonumber(value)
  if n == nil then
    return fallback
  end
  return n
end

local function setting(key, fallback)
  return number(noctalia.getConfig(key), fallback)
end

local function ratioPct(used, total)
  used, total = tonumber(used), tonumber(total)
  if used == nil or total == nil or total <= 0 then
    return nil
  end
  return used / total * 100
end

-- Cada métrica: chave do setting, limite padrão, unidade e como extrair o
-- valor do retorno de systemStats() (nil = sem leitura, ignora).
local METRICS = {
  { key = "cpu_temp", default = 88, label = "CPU", unit = "°C",
    read = function(s) return s.cpu and tonumber(s.cpu.tempC) end },
  { key = "gpu_temp", default = 90, label = "GPU", unit = "°C",
    read = function(s) return s.gpu and tonumber(s.gpu.tempC) end },
  { key = "ram_pct", default = 90, label = "RAM", unit = "%",
    read = function(s) return s.ram and tonumber(s.ram.usagePercent) end },
  { key = "swap_pct", default = 50, label = "Swap", unit = "%",
    read = function(s) return s.swap and ratioPct(s.swap.usedMb, s.swap.totalMb) end },
  { key = "vram_pct", default = 95, label = "VRAM", unit = "%",
    read = function(s)
      return s.gpu and ratioPct(
        number(s.gpu.vramUsedBytes, 0) / BYTES_PER_MIB,
        number(s.gpu.vramTotalBytes, 0) / BYTES_PER_MIB)
    end },
}

-- Estado por métrica: amostras seguidas acima do limite e se ainda pode avisar.
local state = {}
for _, m in METRICS do
  state[m.key] = { above = 0, armed = true }
end

local warnedNoStats = false

local function alert(m, value, limit)
  noctalia.notifyError(
    "Hardware no limite: " .. m.label,
    string.format("%s a %.0f %s (limite %d %s)", m.label, value, m.unit, limit, m.unit))
end

local function check()
  local stats = noctalia.systemStats()
  if type(stats) ~= "table" then
    if not warnedNoStats then
      noctalia.log("hw-alerts: systemStats() indisponível ([system.monitor] desligado?)")
      warnedNoStats = true
    end
    return
  end
  warnedNoStats = false

  local sustain = math.max(1, setting("sustain_samples", 5))
  local hysteresis = math.max(1, setting("hysteresis", 5))

  for _, m in METRICS do
    local value = m.read(stats)
    local st = state[m.key]
    if value ~= nil then
      local limit = setting(m.key, m.default)
      if value >= limit then
        st.above += 1
        if st.armed and st.above >= sustain then
          alert(m, value, limit)
          st.armed = false
        end
      else
        st.above = 0
        if value <= limit - hysteresis then
          st.armed = true
        end
      end
    end
  end
end

function update()
  noctalia.setUpdateInterval(POLL_MS)
  check()
end

function onConfigChanged()
  -- Limite novo: zera a contagem e rearma, pra valer já com o valor atual.
  for _, m in METRICS do
    state[m.key] = { above = 0, armed = true }
  end
  check()
end

function onIpc(event, _payload)
  if event == "test" then
    noctalia.notifyError("Hardware no limite: teste", "Notificação de teste do hw-alerts")
  end
end
