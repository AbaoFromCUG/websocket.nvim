local WebsocketClientable = require("websocket.base")
local protocol = require("websocket.protocol")

---@type {uv:nio.uv}
local a = require("plenary.async")

local client_id = 100

local max_before_frag = math.pow(2, 13) -- 8192

local function nocase(s)
  s = string.gsub(s, "%a", function(c)
    if string.match(c, "[a-zA-Z]") then
      return string.format("[%s%s]", string.lower(c), string.upper(c))
    else
      return c
    end
  end)
  return s
end

local function unmask_text(str, mask)
  local unmasked = {}
  for i = 0, #str - 1 do
    local j = bit.band(i, 0x3)
    local trans = bit.bxor(string.byte(string.sub(str, i + 1, i + 1)), mask[j + 1])
    table.insert(unmasked, trans)
  end
  return unmasked
end

local function convert_bytes_to_string(tab)
  return table.concat(vim.tbl_map(string.char, tab))
end

---@class websocket.Connection: websocket.Clientable
---@field sock uv_tcp_t
---@field id number
local WebsocketConnection = {}
setmetatable(WebsocketConnection, { __index = WebsocketClientable })

---
---@param opt {sock:uv_tcp_t, id:number}
---@return websocket.Connection
function WebsocketConnection:new(opt)
  opt = setmetatable(opt, { __index = self })
  return opt
end

function WebsocketConnection:send_text(str)
  for _, frame in ipairs(protocol.pack(str)) do
    self.sock:write(frame)
  end
end

-- function WebsocketConnection:send_json(obj)
--   local encoded = vim.api.nvim_call_function("json_encode", { obj })
--   self:send_text(encoded)
-- end

function WebsocketConnection:close() end

---@class websocket.Server
local WebsocketServer = {}
WebsocketServer.__index = WebsocketServer

---@class NewWebsocketServerOption
---@field host? string host, default 127.0.0.1
---@field port? number port, default 8080

---
---@param opt? NewWebsocketServerOption
function WebsocketServer:new(opt)
  local o = {}
  o.conns = {}

  opt = vim.tbl_deep_extend("keep", opt or {}, {
    host = "127.0.0.1",
    port = 8080,
  })
  local host = opt.host
  local port = opt.port
  self.server = vim.uv.new_tcp()

  self.server:bind(host, port)

  return setmetatable(o, self)
end

--- start listen
---@param callbacks { on_connect: fun(client:websocket.Connection) }
function WebsocketServer:listen(callbacks)
  local ret, err = self.server:listen(128, function(err)
    assert(err == nil, err)
    local sock = vim.uv.new_tcp()
    self.server:accept(sock)
    ---@type websocket.Connection
    local conn
    local upgraded = false
    local http_data = ""
    local chunk_buffer = ""

    local function getdata(amount)
      while string.len(chunk_buffer) < amount do
        coroutine.yield()
      end
      local retrieved = string.sub(chunk_buffer, 1, amount)
      chunk_buffer = string.sub(chunk_buffer, amount + 1)
      return retrieved
    end

    local wsread_co = coroutine.create(function()
      while true do
        local wsdata = ""
        local fin

        local rec = getdata(2)
        local b1 = string.byte(string.sub(rec, 1, 1))
        local b2 = string.byte(string.sub(rec, 2, 2))
        local opcode = bit.band(b1, 0xF)
        fin = bit.rshift(b1, 7)

        local paylen = bit.band(b2, 0x7F)
        if paylen == 126 then -- 16 bits length
          rec = getdata(2)
          local b3 = string.byte(string.sub(rec, 1, 1))
          local b4 = string.byte(string.sub(rec, 2, 2))
          paylen = bit.lshift(b3, 8) + b4
        elseif paylen == 127 then
          paylen = 0
          rec = getdata(8)
          for i = 1, 8 do -- 64 bits length
            paylen = bit.lshift(paylen, 8)
            paylen = paylen + string.byte(string.sub(rec, i, i))
          end
        end

        local mask = {}
        rec = getdata(4)
        for i = 1, 4 do
          table.insert(mask, string.byte(string.sub(rec, i, i)))
        end

        local data = getdata(paylen)

        local unmasked = unmask_text(data, mask)
        data = convert_bytes_to_string(unmasked)

        wsdata = data

        while fin == 0 do
          rec = getdata(2)
          b1 = string.byte(string.sub(rec, 1, 1))
          b2 = string.byte(string.sub(rec, 2, 2))
          fin = bit.rshift(b1, 7)

          paylen = bit.band(b2, 0x7F)
          if paylen == 126 then -- 16 bits length
            rec = getdata(2)
            local b3 = string.byte(string.sub(rec, 1, 1))
            local b4 = string.byte(string.sub(rec, 2, 2))
            paylen = bit.lshift(b3, 8) + b4
          elseif paylen == 127 then
            paylen = 0
            rec = getdata(8)
            for i = 1, 8 do -- 64 bits length
              paylen = bit.lshift(paylen, 8)
              paylen = paylen + string.byte(string.sub(rec, i, i))
            end
          end

          mask = {}
          rec = getdata(4)
          for i = 1, 4 do
            table.insert(mask, string.byte(string.sub(rec, i, i)))
          end

          data = getdata(paylen)

          unmasked = unmask_text(data, mask)
          data = convert_bytes_to_string(unmasked)

          wsdata = wsdata .. data
        end

        if opcode == 0x1 then -- TEXT
          if conn and conn.callbacks.on_text then
            conn.callbacks.on_text(wsdata)
          end
        end

        if opcode == 0x8 then -- CLOSE
          if conn and conn.callbacks.on_disconnect then
            conn.callbacks.on_disconnect()
          end

          self.conns[conn.id] = nil

          conn.sock:close()
          break
        end
      end
    end)

    sock:read_start(function(err, chunk)
      if chunk then
        if not upgraded then
          http_data = http_data .. chunk
          if string.match(http_data, "\r\n\r\n$") then
            local has_upgrade = false
            local websocketkey
            for line in vim.gsplit(http_data, "\r\n") do
              if string.match(line, "Upgrade: websocket") then
                has_upgrade = true
              elseif string.match(line, nocase("Sec%-WebSocket%-Key")) then
                websocketkey = string.match(line, nocase("Sec%-WebSocket%-Key") .. ": ([=/+%w]+)")
              end
            end

            if has_upgrade then
              sock:write(protocol.pack_upgrade_response(websocketkey))
              upgraded = true

            
              if callbacks.on_connect then
                conn = WebsocketConnection:new({ id = client_id, sock = sock })
                self.conns[client_id] = conn
                client_id = client_id + 1
                callbacks.on_connect(conn)
              end
            end

            http_data = ""
          end
        else
          chunk_buffer = chunk_buffer .. chunk
          coroutine.resume(wsread_co)
        end
      else
        if conn and conn.callbacks and conn.callbacks.on_disconnect then
          conn.callbacks.on_disconnect()
        end

        self.conns[conn.id] = nil

        sock:shutdown()
        sock:close()
      end
    end)
  end)

  if not ret then
    error(err)
  end
end

function WebsocketServer:close()
  for _, conn in pairs(self.conns) do
    if conn and conn.callbacks.on_disconnect then
      conn.callbacks.on_disconnect()
    end

    conn.sock:shutdown()
    conn.sock:close()
  end

  self.conns = {}

  if self.server then
    self.server:close()
    self.server = nil
  end
end

return WebsocketServer
