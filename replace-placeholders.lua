-- Фильтр для замены плейсхолдеров {{АНАЛОГИЯ: ...}}, {{ИСТОРИЯ: ...}}, {{ШУТКА: ...}}

-- Мапинг emoji для замены
local emoji_map = {
  ["✅"] = "[+]",
  ["❌"] = "[-]",
  ["⚠️"] = "[!]",
  ["⚠"] = "[!]",
  ["📊"] = "[STAT]",
  ["🎯"] = "[GOAL]",
  ["💡"] = "[TIP]",
  ["🔥"] = "[HOT]",
  ["⭐"] = "★",
  ["📝"] = "[NOTE]",
  ["🚀"] = "[START]",
  ["🎉"] = "[SUCCESS]",
  ["💼"] = "[WORK]",
  ["📈"] = "[GROWTH]",
  ["🔧"] = "[TOOL]",
  ["📚"] = "[BOOK]",
  ["🎓"] = "[EDU]",
  ["👥"] = "[PEOPLE]",
  ["💰"] = "[MONEY]",
  ["⏰"] = "[TIME]",
  ["🏆"] = "[WIN]",
  ["₽"] = "руб.",
}

-- Читаем файл
local function read_snippet(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  
  -- Убираем технические заголовки
  content = content:gsub("^#[^\n]+\n+", "")
  content = content:gsub("%*%*Контекст%*%*:[^\n]+\n+", "")
  content = content:gsub("^%s+", ""):gsub("%s+$", "")
  
  -- Заменяем emoji
  for emoji, replacement in pairs(emoji_map) do
    content = content:gsub(emoji, replacement)
  end
  
  -- Удаляем вариационные селекторы emoji (U+FE0F и подобные)
  content = content:gsub("[\239\184\128-\239\184\143]", "")  -- U+FE00-U+FE0F
  
  return content
end

function Para(el)
  local text = pandoc.utils.stringify(el)
  
  -- Ищем плейсхолдер
  local placeholder = text:match("{{([^}]+)}}")
  if not placeholder then
    return el
  end
  
  -- Парсим: "АНАЛОГИЯ: глава-01_аналогия_01"
  local ptype, pname = placeholder:match("^([А-ЯЁА-Z]+):%s*(.+)$")
  if not ptype or not pname then
    return el
  end
  
  io.stderr:write("\n🔍 Плейсхолдер: " .. ptype .. " -> " .. pname .. "\n")
  
  -- Определяем путь к папке
  -- При сборке book проекта Pandoc уже в корне книги
  local base_path = ""
  local folder
  
  io.stderr:write("1. Определяем тип папки...\n")
  
  if ptype == "АНАЛОГИЯ" then
    folder = "Аналогии/по-главам/"
    io.stderr:write("2. Тип=АНАЛОГИЯ, folder=" .. folder .. "\n")
  elseif ptype == "ИСТОРИЯ" then
    -- Истории хранятся в Истории/Глава_XX/
    folder = "Истории/"
    io.stderr:write("2. Тип=ИСТОРИЯ, folder=" .. folder .. " (используем Глава_ формат)\n")
  elseif ptype == "ШУТКА" then
    folder = "Шутки/по-главам/"
    io.stderr:write("2. Тип=ШУТКА, folder=" .. folder .. "\n")
  else
    io.stderr:write("2. Неизвестный тип!\n")
    return el
  end
  
  io.stderr:write("3. Извлекаем номер главы из: " .. pname .. "\n")

  -- Извлекаем номер главы и префикс файла
  local chapter_num, file_prefix, chapter

  -- Формат с дефисами: глава-01_аналогия_01
  chapter_num = pname:match("^глава%-([0-9]+)_")
  if chapter_num then
    chapter = "глава-" .. chapter_num
    file_prefix = pname:gsub("^глава%-[0-9]+_", ""):gsub("_", "-")
    io.stderr:write("3.1. Формат с дефисами: глава=" .. chapter .. ", prefix=" .. file_prefix .. "\n")
  else
    -- Формат с подчеркиваниями: глава_01_история_01
    chapter_num = pname:match("^глава_([0-9]+)_")
    if chapter_num then
      if ptype == "ИСТОРИЯ" then
        chapter = "Глава_" .. chapter_num  -- Истории хранятся в папках Глава_XX
      else
        chapter = "глава-" .. chapter_num  -- Аналогии и шутки в папках глава-XX
      end
      file_prefix = pname:gsub("^глава_[0-9]+_", ""):gsub("_", "-")
      io.stderr:write("3.2. Формат с подчеркиваниями: глава=" .. chapter .. ", prefix=" .. file_prefix .. "\n")
    else
      io.stderr:write("❌ Не найдена глава в: " .. pname .. "\n")
      return el
    end
  end

  io.stderr:write("4. Глава: " .. chapter .. ", Префикс: " .. file_prefix .. "\n")

  -- Полный путь к директории
  local dir = base_path .. folder .. chapter .. "/"

  io.stderr:write("5. Директория: " .. dir .. "\n")
  io.stderr:write("📁 Ищем в: " .. dir .. file_prefix .. "*.md\n")

  -- Ищем файл
  local cmd = string.format('find "%s" -maxdepth 1 -name "%s*.md" 2>/dev/null | head -1', dir, file_prefix)
  local handle = io.popen(cmd)
  local file_path = handle:read("*l")
  handle:close()
  
  if not file_path or file_path == "" then
    io.stderr:write("❌ Файл не найден\n")
    return pandoc.Para({
      pandoc.Strong(pandoc.Str("⚠️ Не найден: ")),
      pandoc.Code(placeholder)
    })
  end
  
  io.stderr:write("✅ Найден: " .. file_path .. "\n")
  
  -- Читаем контент
  local content = read_snippet(file_path)
  if not content then
    io.stderr:write("❌ Не удалось прочитать файл\n")
    return el
  end
  
  io.stderr:write("📝 Вставляем " .. #content .. " байт\n")
  
  -- Возвращаем контент как Markdown (Pandoc обработает спецсимволы)
  return pandoc.RawBlock('markdown', '\n\n' .. content .. '\n\n')
end

return {{Para = Para}}

