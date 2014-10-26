do
    local listener = Listener.new("smb2", "smb2")
    local perCommand = {}
    local writtenBytes = 0

    local smb2command = Field.new("smb2.cmd")
    local smb2status = Field.new("smb2.nt_status")
    local smb2wlen = Field.new("smb2.write_length")

    local smb2type = function()
        if smb2status() == nil then
            return "request"
        else
            return "response"
        end
    end

    local issmb2request = function() return smb2status() == nil end



    listener.packet = function(pinfo, tvb, tapinfo)
        local status = smb2status()
        local cmd = smb2command().value
        --print(smb2type() .. " " .. smb2command().display)

        if perCommand[cmd] == nil then
            perCommand[cmd] = {
                name = smb2command().display,
                attempted = 0,
                successful = 0,
                unsuccessful = 0
            }
        end
        local stat = perCommand[cmd]

        if issmb2request() then
            stat.attempted = stat.attempted + 1
        elseif status.value == 0 then
            stat.successful = stat.successful + 1
        else
            stat.unsuccessful = stat.unsuccessful + 1
        end

        if cmd == 9 and issmb2request() then
            writtenBytes = writtenBytes + smb2wlen().value
        end

    end

    listener.draw = function()
        for command, stat in pairs(perCommand) do
            local rem = 25 - #stat.name
            io.write(stat.name)
            for temp = 1, rem do io.write(' ') end
            for temp = 1, stat.unsuccessful do io.write('-') end
            for temp = 1, stat.successful do io.write('+') end
            io.write("\n")
        end

        print()
        print("Total written bytes: " .. tostring(writtenBytes))

    end

end