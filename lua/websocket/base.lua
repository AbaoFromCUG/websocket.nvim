
---@alias websocket.ClientCallbacks {on_disconnect: fun(), on_text: fun(text:string)}

---@class websocket.Clientable
---@field protected sock uv_tcp_t
---@field protected callbacks websocket.ClientCallbacks
---@field send_text fun(self:websocket.Clientable, text: string)
---@field close fun()
local WebsocketClientable = {}

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
    self.sock:shutdown()
    self.sock:close()
    if self.callbacks and self.callbacks.on_disconnect then
        self.callbacks.on_disconnect()
    end
end

return WebsocketClientable
