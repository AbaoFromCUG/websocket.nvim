local a = require("plenary.async")

---@alias websocket.ClientCallbacks {on_disconnect: fun(), on_text: fun(text:string)}

---@class websocket.Clientable
---@field protect sock uv_tcp_t
---@field protect callbacks websocket.ClientCallbacks
---@field send_text fun(self:websocket.Clientable, text: string)
---@field close fun()
local WebsocketClientable = {}

-- ---send text
-- ---@param text string
-- function WebsocketClientable:send_text(text)
--   a.uv.write(self.sock, text)
-- end
--

---set callback
---@param callbacks websocket.ClientCallbacks
function WebsocketClientable:attach(callbacks)
  self.callbacks = callbacks
end

---send json
---@param obj table
function WebsocketClientable:send_json(obj)
  self:send_text(vim.json.encode(obj))
end

---callback when reading
---@param text string
function WebsocketClientable:_on_read(text)
  if self.callbacks and self.callbacks.on_text then
    self.callbacks.on_text(text)
  end
end

---callback when disconnecting
function WebsocketClientable:_on_disconnect()
  if self.callbacks and self.callbacks.on_disconnect then
    self.callbacks.on_disconnect()
  end
end

return WebsocketClientable
