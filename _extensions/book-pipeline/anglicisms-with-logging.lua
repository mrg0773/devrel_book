--[[
Anglicisms Filter WITH DETAILED LOGGING for Quarto Book Pipeline
Purpose: Find English words in Russian text and suggest Russian alternatives

Version: 2.0 (with logging)
Added: 2025-10-26
--]]

-- Whitelist: Technical terms that are acceptable in Russian text
local whitelist = {
  -- DevRel & Tech
  "DevRel", "Developer", "Relations", "API", "SDK", "CLI", "GUI",
  
  -- Cloud & Infrastructure
  "Docker", "Kubernetes", "AWS", "Azure", "GCP", "Cloud", "CI", "CD",
  
  -- Platforms & Tools
  "GitHub", "GitLab", "Slack", "Discord", "Telegram", "Zoom",
  "Jira", "Confluence", "Notion",
  
  -- Programming
  "JavaScript", "TypeScript", "Python", "Java", "Go", "Rust", "C",
  "React", "Vue", "Angular", "Node", "npm", "yarn", "Git",
  
  -- Web & Formats
  "HTML", "CSS", "JSON", "XML", "YAML", "Markdown", "PDF",
  "HTTP", "HTTPS", "REST", "GraphQL", "WebSocket",
  
  -- Databases
  "PostgreSQL", "MySQL", "MongoDB", "Redis", "SQL", "NoSQL",
  
  -- Common abbreviations
  "IT", "PR", "HR", "OK", "etc", "vs",
  
  -- Russian Companies & Platforms (for book context)
  "Яндекс", "VK", "Тинькофф", "Авито", "Озон", "СберТех",
  "Habr", "HeadHunter", "Timepad", "Rutube", "Ozon",
  
  -- Russian specific platforms/terms
  "vc", "ru", "Карьера", "Cloud", "Moscow",
  
  -- DevRel specific
  "Employer", "Brand", "Community", "Manager", "Advocate",
  "NPS", "eNPS", "KPI", "OKR", "ROI", "EVP", "CTR", "MAU", "DAU",
  "B2D", "DX", "DXP", "TA", "UGC", "CFP", "HRBP",
  
  -- Job titles and levels
  "Senior", "senior", "Junior", "junior", "Middle", "Lead", "Head",
  "CEO", "CTO", "CMO", "CHRO", "CFO",
  
  -- Tech companies (international)
  "Google", "Microsoft", "JetBrains", "Stripe", "Twilio", "Vercel",
  "LinkedIn", "YouTube", "Facebook", "Apple",
  
  -- Common tech terms
  "Tech", "tech", "Open", "open", "Source", "source", "Code",
  "DevOps", "Analytics", "Marketing", "Business", "business",
  "Program", "Experience", "Technical", "Pro",
  
  -- Metrics and business
  "Time", "time", "Level", "Rate", "rate", "hire", "Cost", "per",
  "FTE", "chapter",
  
  -- Tools and services
  "Sheets", "CRM", "IDE", "email", "Email",
  
  -- Programming languages
  "Kotlin", "Swift", "Ruby", "PHP",
  
  -- Concepts (устоявшиеся в русском IT)
  "branding", "Branding", "practices", "best",
  
  -- Add more as needed
}

-- Russian alternatives for common English words
local replacements = {
  -- Business
  ["manager"] = "менеджер",
  ["management"] = "управление / менеджмент",
  ["meeting"] = "встреча / митинг",
  ["deadline"] = "дедлайн / срок",
  ["feedback"] = "обратная связь / фидбек",
  ["team"] = "команда",
  ["leader"] = "лидер / руководитель",
  ["project"] = "проект",
  ["task"] = "задача",
  ["goal"] = "цель",
  ["plan"] = "план",
  ["report"] = "отчет",
  ["status"] = "статус",
  ["update"] = "обновление",
  
  -- Communication
  ["call"] = "звонок / созвон",
  ["chat"] = "чат / переписка",
  ["message"] = "сообщение",
  ["email"] = "письмо / email",
  ["newsletter"] = "рассылка",
  ["presentation"] = "презентация",
  ["demo"] = "демо / демонстрация",
  
  -- Development
  ["code"] = "код",
  ["bug"] = "баг / ошибка",
  ["feature"] = "функция / фича",
  ["features"] = "функции / фичи",
  ["release"] = "релиз / выпуск",
  ["version"] = "версия",
  ["build"] = "сборка",
  ["deploy"] = "деплой / развертывание",
  ["deployment"] = "деплой / развертывание",
  ["test"] = "тест / проверка",
  ["review"] = "ревью / проверка",
  ["merge"] = "мерж / слияние",
  ["commit"] = "коммит",
  ["branch"] = "ветка / бранч",
  ["repository"] = "репозиторий",
  ["pull"] = "пул",
  ["request"] = "запрос / реквест",
  ["sprint"] = "спринт",
  ["developer"] = "разработчик",
  
  -- Community
  ["community"] = "сообщество",
  ["event"] = "событие / мероприятие",
  ["workshop"] = "воркшоп / мастер-класс",
  ["hackathon"] = "хакатон",
  ["meetup"] = "митап / встреча",
  ["conference"] = "конференция",
  ["webinar"] = "вебинар",
  
  -- Content
  ["content"] = "контент / содержание",
  ["article"] = "статья",
  ["blog"] = "блог",
  ["post"] = "пост / публикация",
  ["tutorial"] = "туториал / руководство",
  ["guide"] = "гайд / руководство",
  ["documentation"] = "документация",
  
  -- Other
  ["link"] = "ссылка",
  ["file"] = "файл",
  ["folder"] = "папка",
  ["user"] = "пользователь",
  ["admin"] = "администратор",
  ["access"] = "доступ",
  ["permission"] = "разрешение",
  ["setting"] = "настройка",
  ["option"] = "опция / вариант",
  ["search"] = "поиск",
  ["filter"] = "фильтр",
  ["sort"] = "сортировка",
}

-- Report data
local report = {
  found = {},  -- English words found
  whitelisted = {},  -- Technical terms that were whitelisted
  words_scanned = 0,
  words_whitelisted_count = 0,
  words_found_count = 0
}

-- Logging file
local log_file = nil

-- Initialize logging
local function init_logging()
  log_file = io.open("_anglicisms_debug.log", "w")
  if log_file then
    log_file:write("=== ANGLICISMS FILTER DEBUG LOG ===\n")
    log_file:write("Started: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
  end
end

-- Logging function
local function log(msg)
  local timestamp = os.date("%H:%M:%S")
  local log_line = string.format("[%s] %s\n", timestamp, msg)
  
  if log_file then
    log_file:write(log_line)
  end
  io.stderr:write(msg .. "\n")
end

-- Helper: Check if word is in whitelist (case-insensitive)
local function is_whitelisted(word)
  local word_lower = word:lower()
  for _, whitelisted in ipairs(whitelist) do
    if whitelisted:lower() == word_lower then
      return true
    end
  end
  return false
end

-- Helper: Check if word is English (basic heuristic)
local function is_english_word(word)
  -- Only consider words with 3+ letters
  if #word < 3 then
    return false
  end
  
  -- Check if word contains only English letters
  if not word:match("^[a-zA-Z]+$") then
    return false
  end
  
  -- Common English patterns
  local english_patterns = {
    "ing$",  -- talking, meeting
    "tion$", -- presentation, documentation
    "ment$", -- management, deployment
    "ed$",   -- deployed, merged
    "er$",   -- manager, developer
    "ly$",   -- quickly, easily
  }
  
  for _, pattern in ipairs(english_patterns) do
    if word:match(pattern) then
      return true
    end
  end
  
  -- If it's in our replacements dictionary, it's English
  if replacements[word:lower()] then
    return true
  end
  
  return true  -- Assume it's English if it passed other checks
end

-- Track current chapter/file for logging
local current_file = "unknown"

-- Main filter function
function Str(el)
  local text = el.text
  report.words_scanned = report.words_scanned + 1
  
  -- Find English words (sequences of Latin letters)
  for word in text:gmatch("[a-zA-Z]+") do
    if is_english_word(word) then
      if is_whitelisted(word) then
        -- Track whitelisted words
        if not report.whitelisted[word] then
          report.whitelisted[word] = true
        end
        report.words_whitelisted_count = report.words_whitelisted_count + 1
        
        -- Log only in verbose mode
        if os.getenv("DEBUG") == "1" then
          log(string.format("✅ Whitelisted: %s (in file: %s)", word, current_file))
        end
      else
        -- Track non-whitelisted English words
        local suggestion = replacements[word:lower()] or "нет альтернативы"
        
        local item = {
          word = word,
          suggestion = suggestion,
          file = current_file
        }
        table.insert(report.found, item)
        report.words_found_count = report.words_found_count + 1
        
        log(string.format("⚠️  Found anglicism: %s → %s (in: %s)", word, suggestion, current_file))
      end
    end
  end
  
  return el
end

-- Track current file for logging
function Meta(meta)
  local title = meta.title
  if title then
    if title.t == "MetaInlines" then
      -- Extract text from MetaInlines
      for _, el in ipairs(title) do
        if el.t == "Str" then
          current_file = el.text
          log(string.format("\n📄 Processing: %s", current_file))
          break
        end
      end
    end
  end
  return nil
end

-- Generate report at the end
function Pandoc(doc)
  -- Close logging
  if log_file then
    log_file:close()
  end
  
  log("\n=== SUMMARY ===")
  log(string.format("Total words scanned: %d", report.words_scanned))
  log(string.format("Whitelisted: %d", report.words_whitelisted_count))
  log(string.format("Found anglicisms: %d", report.words_found_count))
  
  -- Only generate report if we found something
  if #report.found == 0 and next(report.whitelisted) == nil then
    log("✅ No anglicisms found!")
    return doc
  end
  
  -- Build report content
  local report_lines = {}
  table.insert(report_lines, "# Отчет об англицизмах\n")
  table.insert(report_lines, "*Автоматически создан фильтром anglicisms.lua*\n")
  table.insert(report_lines, string.format("*Дата: %s*\n\n", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(report_lines, "---\n\n")
  
  -- Statistics
  table.insert(report_lines, "## 📊 Статистика\n\n")
  table.insert(report_lines, string.format("- **Всего слов проверено:** %d\n", report.words_scanned))
  table.insert(report_lines, string.format("- **Найдено англицизмов:** %d\n", report.words_found_count))
  table.insert(report_lines, string.format("- **Разрешено (whitelist):** %d\n", report.words_whitelisted_count))
  table.insert(report_lines, "\n")
  
  -- Found anglicisms
  if #report.found > 0 then
    table.insert(report_lines, "## Найденные англицизмы\n\n")
    
    -- Group by word
    local grouped = {}
    for _, item in ipairs(report.found) do
      local word_lower = item.word:lower()
      if not grouped[word_lower] then
        grouped[word_lower] = {
          word = item.word,
          suggestion = item.suggestion,
          count = 0,
          files = {}
        }
      end
      grouped[word_lower].count = grouped[word_lower].count + 1
      table.insert(grouped[word_lower].files, item.file)
    end
    
    -- Sort by word
    local sorted = {}
    for _, data in pairs(grouped) do
      table.insert(sorted, data)
    end
    table.sort(sorted, function(a, b) 
      return a.word:lower() < b.word:lower() 
    end)
    
    table.insert(report_lines, "| Слово | Замена | Встречается | Файлы |\n")
    table.insert(report_lines, "|-------|--------|-------------|-------|\n")
    
    for _, item in ipairs(sorted) do
      -- Create file list (truncate if too many)
      local files_str = table.concat(item.files, ", ")
      if #files_str > 100 then
        files_str = string.sub(files_str, 1, 97) .. "..."
      end
      
      table.insert(report_lines, string.format("| %s | %s | %d | %s |\n", 
        item.word, item.suggestion, item.count, files_str))
    end
    
    table.insert(report_lines, "\n")
    
    table.insert(report_lines, string.format("**Всего найдено:** %d англицизмов\n\n", #report.found))
  else
    table.insert(report_lines, "## Найденные англицизмы\n\n")
    table.insert(report_lines, "\n✅ Англицизмы не найдены!\n\n")
  end
  
  -- Whitelisted terms
  if next(report.whitelisted) ~= nil then
    table.insert(report_lines, "## Разрешенные термины (whitelist)\n")
    table.insert(report_lines, "\nТехнические термины, которые допустимы в тексте:\n\n")
    
    -- Convert to sorted array
    local whitelisted_array = {}
    for word, _ in pairs(report.whitelisted) do
      table.insert(whitelisted_array, word)
    end
    table.sort(whitelisted_array, function(a, b) 
      return a:lower() < b:lower() 
    end)
    
    for _, word in ipairs(whitelisted_array) do
      table.insert(report_lines, string.format("- %s\n", word))
    end
    
    table.insert(report_lines, "\n")
  end
  
  -- Usage recommendations
  table.insert(report_lines, "---\n\n")
  table.insert(report_lines, "## Рекомендации\n\n")
  table.insert(report_lines, "1. **Проверьте найденные англицизмы** - возможно, они нужны для технической точности\n")
  table.insert(report_lines, "2. **Используйте русские альтернативы** там, где это улучшает читаемость\n")
  table.insert(report_lines, "3. **Добавьте в whitelist** термины, которые должны оставаться на английском\n")
  table.insert(report_lines, "4. **Будьте последовательны** - если используете термин, используйте его везде одинаково\n\n")
  
  -- Write report to file
  local report_content = table.concat(report_lines, "")
  local report_file = io.open("_anglicisms_report.md", "w")
  if report_file then
    report_file:write(report_content)
    report_file:close()
    log("✅ Отчет об англицизмах создан: _anglicisms_report.md")
  else
    log("⚠️  Не удалось создать отчет об англицизмах")
  end
  
  -- Summary
  log(string.format("\n✅ Filter completed: %d anglicisms found", #report.found))
  if #report.found > 0 then
    log("📄 See _anglicisms_report.md for details")
  end
  log("📋 Debug log: _anglicisms_debug.log")
  
  return doc
end

-- Initialize logging at start
init_logging()
log("🚀 Anglicisms filter started with logging")

-- Return filter
return {
  { Meta = Meta },
  { Str = Str },
  { Pandoc = Pandoc }
}

