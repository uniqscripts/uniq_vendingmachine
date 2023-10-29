Locales = {}

function L(key)
    local lang = Config.Locale
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