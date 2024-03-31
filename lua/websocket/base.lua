local a = require("plenary.async")

---@alias websocket.ClientCallbacks {on_disconnect: fun(), on_text: fun(text:string)}

---@class websocket.Clientable
---@field private sock uv_tcp_t
---@field private callbacks websocket.ClientCallbacks
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
return WebsocketClientable
