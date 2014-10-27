do
    -- Создаем подписчика, который будет слушать smb2 протокол. 
    --   Первый параметр - что-то типа протокола, который wireshark будет парсить. 
    --   Второй параметр - это фильтр Wireshark, можно писать выражения типа smb2.cmd==create and not(smb2.nt_status)
    local listener = Listener.new("smb2", "smb2")
    
    -- Объявляем таблицу, аналог объекта в js
    local perCommand = {}
    local writtenBytes = 0

    -- Получаем доступ к указанным полям. Поля, опять же, соотв. тем что используются в фильтрах
    local smb2command = Field.new("smb2.cmd")
    local smb2status = Field.new("smb2.nt_status")
    local smb2wlen = Field.new("smb2.write_length")

    -- просто парочка своих функций
    local smb2type = function()
        if smb2status() == nil then
            return "request"
        else
            return "response"
        end
    end

    local issmb2request = function() return smb2status() == nil end


    -- Вызывается для каждого пакета. Что передается в параметрах - пока не понял :) 
    listener.packet = function(pinfo, tvb, tapinfo)
        -- Field.new возвращает функции, вызов которых получает значение поля из текущего пакета
        -- Теперь в status записан объект типа FieldInfo. У него есть полезные методы:
        --  fi.value - получает значение соотв. типа, как правило число. Для команды, кстати, тоже число
        --  fi.display - значение строкой, как его показывает wireshark.
        local status = smb2status()
        local cmd = smb2command().value
        --print(smb2type() .. " " .. smb2command().display)

        -- Тут просто в ассоциативный массив заносятся сведения о каждой из команд
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
        -- cmd == 9 - это WRITE. конечно лучше завеси константы
        if cmd == 9 and issmb2request() then
            writtenBytes = writtenBytes + smb2wlen().value
        end

    end

    -- Эта функция вызывается в самом конце если идет вызов из командной строки
    -- Есть еще вариант написать UI-плагин, который может выводить текст не в консоль, а в окошко внутри wireshark
    -- тогда эта функция будет вызываться раз в какое-то время
    listener.draw = function()
        for command, stat in pairs(perCommand) do
            -- это просто для выравнивания - отбиваем пробелы до 25 символов
            -- #something - получить длину something. вот такой нелепый синтаксис
            local rem = 25 - #stat.name
            io.write(stat.name)
            for temp = 1, rem do io.write(' ') end
            for temp = 1, stat.unsuccessful do io.write('-') end
            for temp = 1, stat.successful do io.write('+') end
            io.write("\n")
        end

        print()
        -- .. - конкатенация строк.
        print("Total written bytes: " .. tostring(writtenBytes))

    end

end
