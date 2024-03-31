# Neovim websocket client&server

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/AbaoFromCUG/websocket.nvim/lint-test.yml?branch=main&style=for-the-badge)
![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)


## Using it


```lua
local websocket = require("websocket")
local server = websocket.Server:new({
    host="127.0.0.1",
    port="9001"
})

server:listen({
    on_connect = function(new_connect)
        new_connect:attach({
            on_text=function()
            end,
            on_disconnect = function()
            end
        })
        new_connect:send_text("Hello")
    end,
})
```



![](https://docs.github.com/assets/cb-36544/images/help/repository/use-this-template-button.png)


## Features and structure

- 100% Lua
- Zero dependencies:
  - running tests using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and [busted](https://olivinelabs.com/busted/)


## Plugins using this
- [neopyter](https://mirrors.sustech.edu.cn/pypi/simple/neopyter/)

### Project structure

``` tree
.
├── LICENSE
├── Makefile
├── README.md
├── doc
│   └── websocket.txt
├── helper.py
├── lua
│   ├── websocket
│   │   ├── base.lua
│   │   ├── client.lua
│   │   ├── protocol.lua
│   │   ├── server.lua
│   │   └── sha1.lua
│   └── websocket.lua
├── plugin
│   └── websocket.lua
└── tests
    ├── minimal_init.lua
    └── websocket
        ├── sha1_spec.lua
        └── websocket_spec.lua
```

