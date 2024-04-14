local sha1 = require("websocket.sha1").sha1
local sha1_binary = require("websocket.sha1").sha1_binary
local a = require("plenary.async")

local websocketMagickey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

describe("sha1", function()
    it("websocket stand", function()
        assert.equal(sha1("dGhlIHNhbXBsZSBub25jZQ=="), "8472ed7f657593c6834197cd8f0dc86b5842c2dd")

        local digest = vim.base64.encode(sha1_binary("dGhlIHNhbXBsZSBub25jZQ==" .. websocketMagickey))
        assert.equal(digest, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    end)

end)
