# Neovim websocket client&server

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/AbaoFromCUG/websocket.nvim/lint-test.yml?branch=main&style=for-the-badge)
![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

## Using it

### Server

```lua
local websocket = require("websocket")
local server = websocket.Server:new({
    host="127.0.0.1",
    port="9001"
})

server:listen({
    on_connect = function(connection)
        connection:attach({
            on_text=function(text)
                new_connect:send_text("Hello")
            end,
            on_disconnect = function()
            end
        })
    end,
})
```

## Features and structure

- 100% Lua
- Zero dependencies:
  - running tests using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and [busted](https://olivinelabs.com/busted/)


## Plugins using this
- [neopyter](https://mirrors.sustech.edu.cn/pypi/simple/neopyter/)

### Project structure

``` tree
.
├── doc
│   └── websocket.txt
├── LICENSE
├── lua
│   ├── websocket
│   │   ├── base.lua
│   │   ├── client.lua
│   │   ├── protocol.lua
│   │   ├── server.lua
│   │   └── sha1.lua
│   └── websocket.lua
├── Makefile
├── plugin
│   └── websocket.lua
├── README.md
└── tests
    ├── helper.py
    ├── minimal_init.lua
    └── websocket
        ├── protocol_spec.lua
        ├── queue_spec.lua
        ├── server_spec.lua
        ├── sha1_spec.lua
        ├── shared.lua
        └── websocket_spec.lua
```

## Acknowledges
* [firenvim](https://github.com/glacambre/firenvim) Embed Neovim in Chrome, Firefox & others.
* [SHA-1 and HMAC-SHA1 Routines in Pure Lua](http://regex.info/blog/lua/sha1)

