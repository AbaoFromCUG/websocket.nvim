local WebsocketServer = require("websocket.server")

local M = {}

local WAIT_TIMEOUT = 10000

--hack vim.system
do
    local vim_system = vim.system
    ---wrap of vim.system
    ---@param cmd string[]
    ---@param opts table
    ---@param on_exit fun(out:{code:number,stdout:string,stderr:string})
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.system = function(cmd, opts, on_exit)
        return vim_system(cmd, opts, vim.schedule_wrap(on_exit))
    end
end

function M.sleep(milliseconds)
    local co = coroutine.running()
    vim.defer_fn(function()
        coroutine.resume(co)
    end, milliseconds)

    return coroutine.yield()
end

function M.range(from, to)
    return function()
        if from < to then
            local v = from
            from = from + 1
            return v
        end
    end
end

---kill process by port
---@param port number
function M.kill_port_process(port)
    local co = coroutine.running()
    vim.system({ "lsof", string.format("-i:%s", port) }, {
        text = true,
    }, function(obj)
        if obj.code == 0 then
            local name, pid = obj.stdout:match("(%w+)%s+(%d+)%s+%w+.*LISTEN")
            vim.system({ "kill", "-9", pid }, { text = true, timeout = 1000 }, function(obj2)
                assert(obj2.code == 0, obj2.stderr)
                coroutine.resume(co)
            end)
        else
            coroutine.resume(co)
        end
    end)
    coroutine.yield()
end

---@class websocket.tests.Queue
---@field private first number
---@field private last number
local Queue = {}
M.Queue = Queue

---@return websocket.tests.Queue
function Queue:new()
    return setmetatable({ first = 0, last = 0 }, {
        __index = self,
        __len = function(obj)
            print(vim.inspect(obj))
            assert(false)
        end,
    })
end

function Queue.size(queue)
    return queue.last - queue.first
end

---push item to tail
---@param queue websocket.tests.Queue
---@param val any
function Queue.push_back(queue, val)
    queue[queue.last] = val
    queue.last = queue.last + 1
end

---pop item from head
---@param queue websocket.tests.Queue
---@return any
function Queue.pop_front(queue)
    assert(queue:size() > 0, "empty queue")
    local val = queue[queue.first]
    queue[queue.first] = nil
    queue.first = queue.first + 1
    return val
end

---pop item from head
---@param queue websocket.tests.Queue
---@return any
function Queue.pop_front_sync(queue)
    vim.wait(WAIT_TIMEOUT, function()
        return queue:size() > 0
    end, 10)
    assert(queue:size() > 0, "empty queue")
    local val = queue[queue.first]
    queue[queue.first] = nil
    queue.first = queue.first + 1
    return val
end

---@class websocket.tests.ClientHelper
---@field send fun(text:string)
---@field recv fun():string
---@field disconnect fun()
---@field wait fun()
---@field is_connected fun():boolean
---@field assert_empty_queue fun()

---construct a fake client
---@param address string
---@param mode string
---@return websocket.tests.ClientHelper
function M.get_fake_client(address, mode)
    local cmd = { "python", "tests/helper.py", "--address", address, "--mode", mode or "client" }
    local read_queue = Queue:new()
    local is_connected = true
    local status, handle = pcall(vim.system, cmd, {
        text = true,
        stdin = true,
        stdout = function(err, data)
            assert(not err, data)
            -- print("vim.system stdout:", vim.inspect(data))
            read_queue:push_back(data)
        end,
    }, function(out)
        if out.code ~= 0 then
            print(vim.inspect(out))
        end
        is_connected = false
        assert(out.code == 0, out.stderr)
    end)

    assert(status and handle ~= nil, handle)

    return {
        send = function(text)
            handle:write(text)
        end,
        recv = function()
            return read_queue:pop_front_sync()
        end,
        is_connected = function()
            return is_connected
        end,
        disconnect = function()
            assert(false)
        end,
        wait = function()
            handle:wait()
        end,
        assert_empty_queue = function()
            if read_queue:size() > 0 then
                assert.is_nil(read_queue:pop_front())
            end
            assert.is_equal(0, read_queue:size(), read_queue)
        end,
    }
end

---@class websocket.tests.ServerHelper
---@field recv_connect fun(): websocket.tests.ClientHelper
---@field block fun()

---construct a server
---@param host string
---@param port number
---@return websocket.tests.ServerHelper
function M.get_server(host, port)
    local connect_queue = Queue:new()

    local server = WebsocketServer:new({
        host = host,
        port = port,
    })
    server:listen({
        on_connect = function(connection)
            -- print("new connection:", connection)
            local read_queue = Queue:new()
            local is_connected = true
            connection:attach({
                on_text = function(text)
                    read_queue:push_back(text)
                end,
                on_disconnect = function()
                    is_connected = false
                end,
            })
            connect_queue:push_back({
                send = function(text)
                    connection:send_text(text)
                end,
                recv = function()
                    return read_queue:pop_front_sync()
                end,
                is_connected = function()
                    return is_connected
                end,
                disconnect = function()
                    connection:close()
                end,
                wait = function()
                    -- andle:wait()
                end,
                assert_empty_queue = function()
                    assert.is_equal(0, connect_queue:size())
                    assert.is_equal(0, read_queue:size())
                end,
            })
        end,
    })

    return {
        recv_connect = function()
            return connect_queue:pop_front_sync()
        end,
    }
end

local function readFile(path)
    local fd = assert(vim.uv.fs_open(path, "r", 438))
    local stat = assert(vim.uv.fs_fstat(fd))
    local data = assert(vim.uv.fs_read(fd, stat.size, 0))
    assert(vim.uv.fs_close(fd))
    return data
end

---@param time? number
---@return string
function M.generate_longstr(time)
    time = time or 1
    local content = readFile("./tests/websocket/shared.lua")
    local data = ""
    for i in M.range(0, time) do
        data = data .. content
    end
    return data
end

return M
