--[[
Placeholders Filter for Quarto Book Pipeline
Purpose: Replace {{TYPE name}} with snippet contents

Usage:
  Add to _quarto.yml:
    filters:
      - placeholders.lua

Supported placeholders:
  {{STORY name}}      → snippets/stories/name.md
  {{RESEARCH name}}   → snippets/research/name.md
  {{QUOTE name}}      → snippets/quotes/name.md
  {{CHECKLIST name}}  → snippets/checklists/name.md
  {{TEMPLATE name}}   → snippets/templates/name.md
  {{EXAMPLE name}}    → snippets/examples/name.md
  {{SUMMARY name}}    → snippets/summaries/name.md
  {{TIP name}}        → snippets/tips/name.md
--]]

-- Type to folder mapping
local type_map = {
  STORY = "stories",
  RESEARCH = "research",
  QUOTE = "quotes",
  CHECKLIST = "checklists",
  TEMPLATE = "templates",
  EXAMPLE = "examples",
  SUMMARY = "summaries",
  TIP = "tips",
}

-- Cache for loaded snippets (key: "TYPE/name", value: parsed content)
local cache = {}

-- Statistics
local stats = {
  loaded = {},      -- Successfully loaded snippets
  missing = {},     -- Missing snippets
  cache_hits = 0,   -- Number of cache hits
}

-- Helper: Read and parse snippet file
local function read_snippet(type_name, snippet_name)
  local cache_key = type_name .. "/" .. snippet_name
  
  -- Check cache first
  if cache[cache_key] then
    stats.cache_hits = stats.cache_hits + 1
    return cache[cache_key], nil
  end
  
  -- Get folder name from type
  local folder = type_map[type_name]
  if not folder then
    return nil, string.format("Unknown placeholder type: %s", type_name)
  end
  
  -- Construct file path
  local file_path = string.format("snippets/%s/%s.md", folder, snippet_name)
  
  -- Try to read file
  local file, err = io.open(file_path, "r")
  if not file then
    return nil, string.format("Snippet not found: %s (type: %s)", snippet_name, type_name)
  end
  
  -- Read content
  local content = file:read("*all")
  file:close()
  
  if not content or content == "" then
    return nil, string.format("Snippet is empty: %s", file_path)
  end
  
  -- Parse as Markdown
  local success, parsed = pcall(function()
    return pandoc.read(content, "markdown")
  end)
  
  if not success then
    return nil, string.format("Failed to parse snippet: %s", file_path)
  end
  
  -- Cache the result
  cache[cache_key] = parsed.blocks
  
  -- Track statistics
  table.insert(stats.loaded, {
    type = type_name,
    name = snippet_name,
    path = file_path
  })
  
  return parsed.blocks, nil
end

-- Helper: Check if text contains placeholder pattern
local function find_placeholder(text)
  -- Pattern: {{TYPE name}} or {{TYPE name-with-dashes}}
  local pattern = "{{(%u+)%s+([%w%-_]+)}}"
  local type_name, snippet_name = text:match(pattern)
  return type_name, snippet_name
end

-- Main filter function for Block elements
function Block(el)
  -- Only process Para and Plain blocks that might contain placeholders
  if el.t ~= "Para" and el.t ~= "Plain" then
    return nil
  end
  
  -- Check if block contains a single Str element with placeholder
  if #el.content == 1 and el.content[1].t == "Str" then
    local text = el.content[1].text
    local type_name, snippet_name = find_placeholder(text)
    
    if type_name and snippet_name then
      -- Load snippet
      local blocks, err = read_snippet(type_name, snippet_name)
      
      if blocks then
        -- Return the loaded blocks
        return blocks
      else
        -- Track missing snippet
        table.insert(stats.missing, {
          type = type_name,
          name = snippet_name,
          error = err
        })
        
        -- Return error message
        local error_div = pandoc.Div(
          {
            pandoc.Para({
              pandoc.Strong(pandoc.Str("⚠️  Placeholder Error: ")),
              pandoc.Str(err)
            })
          },
          pandoc.Attr("", {"placeholder-error"}, {})
        )
        return error_div
      end
    end
  end
  
  -- Check if block contains multiple elements (placeholder might be split)
  -- This handles cases where {{TYPE name}} is split into multiple Str elements
  local full_text = ""
  for _, inline in ipairs(el.content) do
    if inline.t == "Str" then
      full_text = full_text .. inline.text
    elseif inline.t == "Space" then
      full_text = full_text .. " "
    end
  end
  
  local type_name, snippet_name = find_placeholder(full_text)
  if type_name and snippet_name then
    local blocks, err = read_snippet(type_name, snippet_name)
    
    if blocks then
      return blocks
    else
      table.insert(stats.missing, {
        type = type_name,
        name = snippet_name,
        error = err
      })
      
      local error_div = pandoc.Div(
        {
          pandoc.Para({
            pandoc.Strong(pandoc.Str("⚠️  Placeholder Error: ")),
            pandoc.Str(err)
          })
        },
        pandoc.Attr("", {"placeholder-error"}, {})
      )
      return error_div
    end
  end
  
  return nil
end

-- Generate statistics report at the end
function Pandoc(doc)
  -- Only generate report if there were any placeholder operations
  if #stats.loaded == 0 and #stats.missing == 0 then
    return doc
  end
  
  -- Build report
  local report_lines = {}
  table.insert(report_lines, "# Placeholders Report\n")
  table.insert(report_lines, "*Автоматически создан фильтром placeholders.lua*\n")
  table.insert(report_lines, "---\n\n")
  
  -- Successfully loaded snippets
  if #stats.loaded > 0 then
    table.insert(report_lines, "## ✅ Загруженные снипеты\n\n")
    
    -- Group by type
    local by_type = {}
    for _, item in ipairs(stats.loaded) do
      if not by_type[item.type] then
        by_type[item.type] = {}
      end
      table.insert(by_type[item.type], item)
    end
    
    -- Output by type
    for type_name, items in pairs(by_type) do
      table.insert(report_lines, string.format("### %s (%d)\n\n", type_name, #items))
      for _, item in ipairs(items) do
        table.insert(report_lines, string.format("- `%s` → %s\n", item.name, item.path))
      end
      table.insert(report_lines, "\n")
    end
    
    table.insert(report_lines, string.format("**Всего загружено:** %d снипетов\n\n", #stats.loaded))
  end
  
  -- Cache statistics
  if stats.cache_hits > 0 then
    table.insert(report_lines, "## 📊 Кэш\n\n")
    table.insert(report_lines, string.format("- Попадания в кэш: %d\n", stats.cache_hits))
    table.insert(report_lines, string.format("- Уникальных снипетов: %d\n", #stats.loaded))
    table.insert(report_lines, string.format("- Эффективность: %.1f%%\n\n", 
      stats.cache_hits / (#stats.loaded + stats.cache_hits) * 100))
  end
  
  -- Missing snippets (errors)
  if #stats.missing > 0 then
    table.insert(report_lines, "## ❌ Ошибки\n\n")
    table.insert(report_lines, "Следующие снипеты не найдены:\n\n")
    
    for _, item in ipairs(stats.missing) do
      table.insert(report_lines, string.format("- **{{%s %s}}** - %s\n", 
        item.type, item.name, item.error))
    end
    
    table.insert(report_lines, "\n### Рекомендации\n\n")
    table.insert(report_lines, "1. Проверьте, что файлы существуют в правильных папках\n")
    table.insert(report_lines, "2. Проверьте правильность имен файлов (регистр важен!)\n")
    table.insert(report_lines, "3. Убедитесь, что используете поддерживаемые типы:\n")
    table.insert(report_lines, "   - STORY, RESEARCH, QUOTE, CHECKLIST\n")
    table.insert(report_lines, "   - TEMPLATE, EXAMPLE, SUMMARY, TIP\n\n")
  end
  
  -- Supported types reference
  table.insert(report_lines, "---\n\n")
  table.insert(report_lines, "## 📚 Поддерживаемые типы\n\n")
  table.insert(report_lines, "| Тип | Папка | Описание |\n")
  table.insert(report_lines, "|-----|-------|----------|\n")
  table.insert(report_lines, "| `{{STORY name}}` | snippets/stories/ | Истории успеха, кейсы |\n")
  table.insert(report_lines, "| `{{RESEARCH name}}` | snippets/research/ | Исследования, данные |\n")
  table.insert(report_lines, "| `{{QUOTE name}}` | snippets/quotes/ | Цитаты |\n")
  table.insert(report_lines, "| `{{CHECKLIST name}}` | snippets/checklists/ | Чек-листы |\n")
  table.insert(report_lines, "| `{{TEMPLATE name}}` | snippets/templates/ | Шаблоны |\n")
  table.insert(report_lines, "| `{{EXAMPLE name}}` | snippets/examples/ | Примеры кода |\n")
  table.insert(report_lines, "| `{{SUMMARY name}}` | snippets/summaries/ | Резюме |\n")
  table.insert(report_lines, "| `{{TIP name}}` | snippets/tips/ | Советы |\n\n")
  
  -- Write report
  local report_content = table.concat(report_lines, "")
  local report_file = io.open("_placeholders_report.md", "w")
  if report_file then
    report_file:write(report_content)
    report_file:close()
    io.stderr:write("✅ Отчет о плейсхолдерах создан: _placeholders_report.md\n")
  else
    io.stderr:write("⚠️  Не удалось создать отчет о плейсхолдерах\n")
  end
  
  return doc
end

-- Return filter
return {
  { Block = Block },
  { Pandoc = Pandoc }
}

