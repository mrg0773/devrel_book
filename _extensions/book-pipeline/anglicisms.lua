--[[
Anglicisms Filter for Quarto Book Pipeline
Purpose: Find English words in Russian text and suggest Russian alternatives

Usage:
  Add to _quarto.yml:
    filters:
      - anglicisms.lua

This filter will:
1. Scan Russian text for English words
2. Check against whitelist (technical terms that are OK)
3. Generate a report with suggestions
4. Output: _anglicisms_report.md
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
  whitelisted = {}  -- Technical terms that were whitelisted
}

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

-- Main filter function
function Str(el)
  local text = el.text
  
  -- Find English words (sequences of Latin letters)
  for word in text:gmatch("[a-zA-Z]+") do
    if is_english_word(word) then
      if is_whitelisted(word) then
        -- Track whitelisted words
        if not report.whitelisted[word] then
          report.whitelisted[word] = true
        end
      else
        -- Track non-whitelisted English words
        local suggestion = replacements[word:lower()] or "нет альтернативы"
        table.insert(report.found, {
          word = word,
          suggestion = suggestion
        })
      end
    end
  end
  
  return el
end

-- Generate report at the end
function Pandoc(doc)
  -- Only generate report if we found something
  if #report.found == 0 and next(report.whitelisted) == nil then
    return doc
  end
  
  -- Build report content
  local report_lines = {}
  table.insert(report_lines, "# Отчет об англицизмах\n")
  table.insert(report_lines, "*Автоматически создан фильтром anglicisms.lua*\n")
  table.insert(report_lines, "---\n\n")
  
  -- Found anglicisms
  if #report.found > 0 then
    table.insert(report_lines, "## Найденные англицизмы\n")
    table.insert(report_lines, "\nАнглийские слова в русском тексте:\n\n")
    
    -- Sort by word
    table.sort(report.found, function(a, b) 
      return a.word:lower() < b.word:lower() 
    end)
    
    for _, item in ipairs(report.found) do
      table.insert(report_lines, string.format("- **%s** → %s\n", item.word, item.suggestion))
    end
    
    table.insert(report_lines, string.format("\n**Всего найдено:** %d англицизмов\n\n", #report.found))
  else
    table.insert(report_lines, "## Найденные англицизмы\n")
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
    io.stderr:write("✅ Отчет об англицизмах создан: _anglicisms_report.md\n")
  else
    io.stderr:write("⚠️  Не удалось создать отчет об англицизмах\n")
  end
  
  return doc
end

-- Return filter
return {
  { Str = Str },
  { Pandoc = Pandoc }
}

