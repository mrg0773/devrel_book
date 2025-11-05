-- Фильтр для замены плейсхолдеров <TERM:...>> на термины из glossary/terms.yml
-- Версия 2: Улучшенная обработка HTML RawInline элементов

-- Simple YAML parser for basic glossary format
local function parse_yaml(content)
    local terms = {}
    local in_terms = false
    local current_term = nil

    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace

        if line == "terms:" then
            in_terms = true
        elseif in_terms and line:match("^%- term:") then
            -- Извлекаем ключ термина
            current_term = line:match('term: "([^"]+)"')
        elseif in_terms and current_term and line:match("^%s*definition:") then
            -- Извлекаем значение (definition)
            local definition = line:match('definition: "([^"]+)"')
            if definition then
                -- Сохраняем соответствие ключ -> значение
                terms[current_term] = definition
                -- Также добавляем вариант с нижним регистром для надежности
                terms[current_term:lower()] = definition
            end
            current_term = nil
        end
    end

    return terms
end

-- Load glossary from YAML file
local glossary_terms = {}
local glossary_loaded = false

local function load_glossary()
    if glossary_loaded then
        return
    end

    local glossary_file = "glossary/terms.yml"
    local file = io.open(glossary_file, "r")

    if not file then
        io.stderr:write("Warning: glossary/terms.yml not found. Term replacement disabled.\n")
        glossary_loaded = true
        return
    end

    local content = file:read("*all")
    file:close()

    glossary_terms = parse_yaml(content)
    glossary_loaded = true

    local count = 0
    for _ in pairs(glossary_terms) do count = count + 1 end
    io.stderr:write("📖 Loaded " .. count .. " terms from glossary\n")
end

-- Process Inlines to handle sequences of elements
function Inlines(inlines)
    load_glossary()

    local new_inlines = pandoc.List()
    local i = 1

    while i <= #inlines do
        local elem = inlines[i]

        -- Check if this is an HTML RawInline with a TERM tag
        if elem.t == "RawInline" and elem.format == "html" then
            local term_key = elem.text:match("<TERM:([^>]+)>")

            if term_key then
                -- Find replacement
                local replacement = glossary_terms[term_key] or
                                   glossary_terms[term_key:lower()] or
                                   glossary_terms[term_key:lower():gsub("%s+", "_"):gsub("%-", "_")]

                if replacement then
                    io.stderr:write("✅ Replaced <TERM:" .. term_key .. ">> → " .. replacement .. "\n")
                    new_inlines:insert(pandoc.Str(replacement))
                else
                    io.stderr:write("⚠️  No replacement for <TERM:" .. term_key .. ">> (keeping as: " .. term_key .. ")\n")
                    new_inlines:insert(pandoc.Str(term_key))
                end

                -- Check if the next element is a Str starting with >
                if i + 1 <= #inlines and inlines[i + 1].t == "Str" then
                    local next_str = inlines[i + 1].text
                    if next_str:sub(1, 1) == ">" then
                        -- Skip the > and add the rest if there's anything
                        local rest = next_str:sub(2)
                        if rest ~= "" then
                            new_inlines:insert(pandoc.Str(rest))
                        end
                        i = i + 1  -- Skip the next element
                    end
                end
            else
                -- Not a TERM tag, keep as is
                new_inlines:insert(elem)
            end
        else
            -- Regular element, keep it
            new_inlines:insert(elem)
        end

        i = i + 1
    end

    return new_inlines
end

-- Also process Str elements for any remaining cases
function Str(el)
    load_glossary()
    local text = el.text

    -- Check for plain TERM tags (shouldn't happen but just in case)
    local new_text = text:gsub("<TERM:([^>]+)>>", function(term_key)
        local replacement = glossary_terms[term_key] or
                           glossary_terms[term_key:lower()] or
                           glossary_terms[term_key:lower():gsub("%s+", "_"):gsub("%-", "_")]

        if replacement then
            io.stderr:write("✅ Replaced <TERM:" .. term_key .. ">> → " .. replacement .. " (in Str)\n")
            return replacement
        else
            io.stderr:write("⚠️  No replacement for <TERM:" .. term_key .. ">> (keeping as: " .. term_key .. ")\n")
            return term_key
        end
    end)

    if new_text ~= text then
        return pandoc.Str(new_text)
    end
end

return {
    {Inlines = Inlines},
    {Str = Str}
}