Locales = {}
local lang = lib.require('config.config').Locale

function L(key)
    local value = Locales[lang]

    for k in key:gmatch("[^.]+") do
        value = value[k]

        if not value then
            print("Missing locale for: " .. key)
            return ""
        end
    end

    return value
end