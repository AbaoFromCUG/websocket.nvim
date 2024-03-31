local WebsocketServer = require("websocket.server")
local mock = require("luassert.mock")
local stub = require("luassert.stub")
local spy = require("luassert.spy")

---kill process by port
---@param port number
local function kill_port_process(port)
  local co = coroutine.running()
  vim.system({ "lsof", string.format("-i:%s", port) }, {
    text = true,
  }, function(obj)
    if obj.code == 0 then
      local name, pid = obj.stdout:match("(%w+)%s+(%d+)%s+%w+.*LISTEN")
      -- print(name, pid)
      vim.system({ "kill", "-9", pid }, { text = true, timeout = 1000 }, function(obj2)
        -- print(string.format("kill process [%s] with pid:", name, pid) .. pid)
        vim.defer_fn(function()
          coroutine.resume(co)
        end, 1000)
      end)
    else
      coroutine.resume(co)
    end
  end)
  coroutine.yield()
end

describe("transport", function()
  describe("simple", function()
    --- server->client
    it("server->client", function()
      kill_port_process(9002)
      local co = coroutine.running()
      local client_rec = spy.new(function() end)
      local server = WebsocketServer:new({
        host = "127.0.0.1",
        port = 9002,
      })
      server:listen({
        on_connect = function(connect)
          -- print(vim.inspect(connect))
          connect:send_text("Hello")
          connect:attach({
            on_disconnect = function()
              -- defer for vim.system exit
              vim.defer_fn(function()
                -- print("simple", coroutine.status(co))
                coroutine.resume(co)
              end, 100)
            end,
          })
        end,
      })
      vim.system({ "python", "helper.py", "--address", "ws://127.0.0.1:9002", "--mode", "printer" }, {
        text = true,
      }, function(out)
        assert(out.code == 0, out.stderr)
        client_rec(out.stdout)
      end)
      coroutine.yield()
      assert.spy(client_rec).was.called_with("Hello")
    end)

    --- client->server->client
    it("client->server->client", function()
      kill_port_process(9003)
      local co = coroutine.running()
      local client_rec = spy.new(function() end)
      local server = WebsocketServer:new({
        host = "127.0.0.1",
        port = 9003,
      })
      server:listen({
        on_connect = function(connect)
          -- print(vim.inspect(connect))
          connect:attach({
            on_text = function(text)
              connect:send_text(text)
            end,
            on_disconnect = function()
              vim.defer_fn(function()
                -- print("echo", coroutine.status(co))
                coroutine.resume(co)
              end, 1000)
            end,
          })
        end,
      })
      vim.system(
        { "python", "helper.py", "--address", "ws://127.0.0.1:9003", "--mode", "echo", "--content", "Hello" },
        {
          text = true,
        },
        function(out)
          assert(out.code == 0, out.stderr)
          client_rec(out.stdout)
        end
      )
      coroutine.yield()
      assert.spy(client_rec).was.called_with("Hello")
    end)

    -- client1->server->client2
    it("client1->server->cllient2", function()
      kill_port_process(9004)
      local co = coroutine.running()
      local server = WebsocketServer:new({
        host = "127.0.0.1",
        port = 9004,
      })
      ---@type websocket.Connection
      local first_connect, second_connect
      server:listen({
        on_connect = function(connect)
          -- print(vim.inspect(connect))
          if first_connect == nil then
            first_connect = connect
            connect:attach({
              on_text = function(text)
                -- print("text rec", text)
                -- defer ensure second client connected
                vim.defer_fn(function()
                  second_connect:send_text(text)
                end, 1000)
              end,
              on_disconnect = function() end,
            })
          elseif second_connect == nil then
            second_connect = connect
          end
        end,
      })

      vim.system(
        { "python", "helper.py", "--address", "ws://127.0.0.1:9004", "--mode", "dual", "--content", "Hello" },
        {
          text = true,
        },
        function(out)
          assert(out.code == 0, out.stderr)
          assert(out.stdout == "Hello")
          -- print("loop", coroutine.status(co))
          coroutine.resume(co)
        end
      )
      coroutine.yield()
    end)
  end)

  describe("big data", function()
    --- server manual
    it("server->client", function() end)
  end)
end)
