local protocol = require("websocket.protocol")
local generate_longstr = require("tests.websocket.shared").generate_longstr

describe("pack", function()
    it("big data", function()
        local data = generate_longstr(10)
        local frames = protocol.to_frame(data)
        local total_payload_length = 0
        ---@param frame websocket.ProtocolFrame
        frames = vim.tbl_map(function(frame)
            total_payload_length = total_payload_length + #frame.payload
            return {
                fin = frame.fin,
                opcode = frame.opcode,
                mask = frame.mask,
                length = #frame.payload,
            }
        end, frames)

        assert.is_equal(#data, total_payload_length)
        for i, frame in ipairs(frames) do
            if i == 1 then
                assert.is_equal(1, frame.opcode)
                assert.is_equal(0, frame.fin)
            elseif i == #frames then
                assert.is_equal(0, frame.opcode)
                assert.is_equal(1, frame.fin)
            else
                assert.is_equal(0, frame.opcode)
                assert.is_equal(0, frame.fin)
            end
        end
    end)
end)
