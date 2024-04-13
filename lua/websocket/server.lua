local WebsocketClientable = require("websocket.base")
local protocol = require("websocket.protocol")

local client_id = 100

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
---@return websocket.Connection
function WebsocketConnection:new(sock)
    local o = setmetatable({}, { __index = self })
    o.sock = sock
    o.id = client_id
    client_id = client_id + 1
    return o
end

function WebsocketConnection:send_text(str)
    for _, frame in ipairs(protocol.pack(str)) do
        self.sock:write(frame)
    end
end

function WebsocketConnection:close()
    self:_on_disconnect()
end

---@class websocket.Server
---@field host string
---@field port number
---@field subprotocols string[]
local WebsocketServer = {}
WebsocketServer.__index = WebsocketServer

---@class NewWebsocketServerOption
---@field host? string host, default 127.0.0.1
---@field port? number port, default 8080
---@field subprotocols? string[]

---
---@param opt? NewWebsocketServerOption
---@return websocket.Server
function WebsocketServer:new(opt)
    local o = vim.tbl_deep_extend("keep", opt or {}, { host = "127.0.0.1", port = 8080, subprotocols = {} }) --[[@as websocket.Server]]
    o.conns = {}
    setmetatable(o, self)
    return o
end

--- start listen
---@param callbacks { on_connect: fun(client:websocket.Connection) }
function WebsocketServer:listen(callbacks)
    self.server = vim.uv.new_tcp()
    self.server:bind(self.host, self.port)
    local on_listen = function(err)
        assert(err == nil, err)
        local sock = vim.uv.new_tcp()
        self.server:accept(sock)

        local function establish()
            local upgraded = false
            local http_data = ""
            local chunk_buffer = ""
            ---@type websocket.Connection
            local connection = nil

            local function release_sock()
                sock:shutdown()
                sock:close()
            end

            local function getdata(amount)
                while string.len(chunk_buffer) < amount do
                    coroutine.yield()
                end
                local retrieved = string.sub(chunk_buffer, 1, amount)
                chunk_buffer = string.sub(chunk_buffer, amount + 1)
                return retrieved
            end

            local wsread = coroutine.wrap(function()
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
                        connection:_on_read(wsdata)
                    end

                    if opcode == 0x8 then -- CLOSE
                        connection:_on_disconnect()
                        break
                    end
                end
            end)

            sock:read_start(function(err, chunk)
                if chunk then
                    if not upgraded then
                        http_data = http_data .. chunk
                        if protocol.is_http_header(http_data) then
                            local websocketkey
                            for line in vim.gsplit(http_data, "\r\n") do
                                if string.match(line, "Upgrade: websocket") then
                                    upgraded = true
                                elseif string.match(line, nocase("Sec%-WebSocket%-Key")) then
                                    websocketkey = string.match(line, nocase("Sec%-WebSocket%-Key") .. ": ([=/+%w]+)")
                                end
                            end
                            http_data = ""
                            if upgraded then
                                -- establish handshake
                                sock:write(protocol.pack_upgrade_response(websocketkey, self.subprotocols))
                                connection = WebsocketConnection:new(sock)
                                if callbacks.on_connect then
                                    self.conns[connection.id] = connection
                                    callbacks.on_connect(connection)
                                end
                            else
                                release_sock()
                            end
                        end
                    else
                        chunk_buffer = chunk_buffer .. chunk
                        wsread()
                    end
                elseif connection ~= nil then
                    connection:_on_disconnect()
                else
                    release_sock()
                end
            end)
        end

        establish()
    end
    local ret, err = self.server:listen(128, on_listen)
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
