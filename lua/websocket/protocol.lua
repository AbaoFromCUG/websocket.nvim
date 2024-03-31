local sha1 = require("websocket.sha1")

local M = {}

local function bytes2string(bytes)
  return table.concat(vim.tbl_map(string.char, bytes))
end

---create response body
---@param client_sec_key any
function M.pack_upgrade_response(client_sec_key)
  local digest = sha1.sha1_binary(client_sec_key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
  local hashed = vim.base64.encode(digest)
  return table.concat({
    "HTTP/1.1 101 Switching Protocols\r\n",
    "Upgrade: websocket\r\n",
    "Connection: Upgrade\r\n",
    "Sec-WebSocket-Accept: " .. hashed .. "\r\n",
    "Sec-WebSocket-Protocol: chat\r\n",
    "\r\n",
  })
end

---@class websocket.ProtocolFrame
---@field fin 0|1
---@field rsv1? 0|1
---@field rsv2? 0|1
---@field rsv3? 0|1
---@field mask? 0|1
---@field opcode number 0x1-0xF 4bit number
---@field payload string

---comment
---@param frame websocket.ProtocolFrame
function M.pack_frame(frame)
  local bytes = { 0, 0 }
  if frame.fin == 1 then
    bytes[1] = 0x80
  end
  if frame.rsv1 == 1 then
    bytes[1] = bytes[1] + 0x40
  end
  if frame.rsv2 == 1 then
    bytes[1] = bytes[1] + 0x20
  end
  if frame.rsv3 == 1 then
    bytes[1] = bytes[1] + 0x10
  end
  bytes[1] = bytes[1] + frame.opcode

  local length = #frame.payload

  if length <= 125 then
    bytes[2] = bytes[2] + length
  elseif length < math.pow(2, 16) then
    bytes[2] = bytes[2] + 126
    local b1 = bit.rshift(length, 8)
    local b2 = bit.band(length, 0xFF)
    table.insert(bytes, b1)
    table.insert(bytes, b2)
  else
    bytes[2] = bytes[2] + 127
    for i = 0, 7 do
      local b = bit.band(bit.rshift(length, (7 - i) * 8), 0xFF)
      table.insert(bytes, b)
    end
  end
  -- print(vim.inspect(bytes))
  return bytes2string(bytes) .. frame.payload
end

local max_before_frag = math.pow(2, 13) -- 8192

---pack payload as frames
---@param message string
function M.pack(message)
  local remain = #message
  local sent = 0
  local frames = {}
  while remain > 0 do
    local send = math.min(max_before_frag, remain) -- max size before fragment
    remain = remain - send
    local payload = string.sub(message, 1, send)
    local frame = M.pack_frame({
      fin = remain == 0 and 1 or 0,
      opcode = sent == 0 and 0x1 or 1,
      payload = payload,
    })
    table.insert(frames, frame)
    message = string.sub(message, send + 1)
    sent = sent + send
  end
  return frames
end

return M
