local WebsocketServer = require("websocket.server")
local WebsocketClient = require("websocket.client")

return {
    Server = WebsocketServer,
    Client = WebsocketClient,
}
