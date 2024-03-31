

---@class WebsocketClient
---@field sock uv_tcp_t
---@field id number
local WebsocketClient = {}
WebsocketClient.__index = WebsocketClient

---
---@param opt {sock:uv_tcp_t, id:number}
function WebsocketClient:new(opt)
  opt = setmetatable(opt, self)
  return opt
end

---
---@param callbacks websocket.ClientCallbacks
function WebsocketClient:attach(callbacks)
end

function WebsocketClient:send_text(str)
end

