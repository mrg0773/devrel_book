--[[
Check Cross-References Filter for Quarto Book Pipeline
Purpose: Validate internal references to chapters and appendices

Usage:
  Add to _quarto.yml:
    filters:
      - check-cross-references.lua

This filter will:
1. Scan text for chapter/appendix references
2. Check if referenced content exists
3. Generate a report with broken/suspicious references
4. Output: _cross_references_report.md
--]]

-- Patterns for finding references
local reference_patterns = {
  -- Russian patterns
  "как мы обсуждали в главе (%d+)",
  "как обсуждали в главе (%d+)",
  "см%. главу (%d+)",
  "см%. Главу (%d+)",
  "смотри главу (%d+)",
  "в главе (%d+)",
  "Глава (%d+)",
  "главе (%d+)",
  "Приложени[ея] ([А-Я])",
  "приложени[ея] ([А-Я])",
  "см%. Приложение ([А-Я])",
  "см%. приложение ([А-Я])",
}

-- Known chapters (1-18) and appendices (А, Б, В)
local valid_chapters = {}
for i = 1, 18 do
  valid_chapters[tostring(i)] = true
end

local valid_appendices = {
  ["А"] = "Приложение А (Ресурсы)",
  ["Б"] = "Приложение Б (Шаблоны)",
  ["В"] = "Приложение В (Глоссарий)"
}

-- Global state
local references_found = {}
local current_file = "unknown"

-- Helper: extract references from text
local function extract_references(text)
  local refs = {}
  
  for _, pattern in ipairs(reference_patterns) do
    for match in text:gmatch(pattern) do
      table.insert(refs, {
        type = match:match("^%d+$") and "chapter" or "appendix",
        ref = match,
        pattern = pattern,
        context = text:sub(math.max(1, text:find(pattern) - 50), math.min(#text, text:find(pattern) + 100))
      })
    end
  end
  
  return refs
end

-- Helper: validate reference
local function validate_reference(ref)
  if ref.type == "chapter" then
    return valid_chapters[ref.ref] == true
  elseif ref.type == "appendix" then
    return valid_appendices[ref.ref] ~= nil
  end
  return false
end

-- Process Str elements
local function check_str(elem)
  local text = elem.text
  local refs = extract_references(text)
  
  for _, ref in ipairs(refs) do
    local is_valid = validate_reference(ref)
    
    table.insert(references_found, {
      ref = ref.ref,
      type = ref.type,
      valid = is_valid,
      file = current_file,
      context = ref.context,
      pattern = ref.pattern
    })
  end
  
  return elem
end

-- Process Para elements (paragraphs might have full context)
local function check_para(elem)
  -- Convert para to plain text
  local text = pandoc.utils.stringify(elem)
  local refs = extract_references(text)
  
  for _, ref in ipairs(refs) do
    local is_valid = validate_reference(ref)
    
    table.insert(references_found, {
      ref = ref.ref,
      type = ref.type,
      valid = is_valid,
      file = current_file,
      context = text:sub(1, math.min(150, #text)),
      pattern = ref.pattern
    })
  end
  
  return elem
end

-- Generate report
local function generate_report(doc)
  if #references_found == 0 then
    print("✓ Cross-references check: no references found to validate")
    return doc
  end
  
  -- Separate valid and invalid
  local invalid_refs = {}
  local valid_refs = {}
  
  for _, ref in ipairs(references_found) do
    if ref.valid then
      table.insert(valid_refs, ref)
    else
      table.insert(invalid_refs, ref)
    end
  end
  
  -- Build report
  local report_lines = {
    "# Cross-References Report",
    "",
    string.format("Total references found: %d", #references_found),
    string.format("Valid references: %d", #valid_refs),
    string.format("**Invalid/suspicious references: %d**", #invalid_refs),
    "",
  }
  
  if #invalid_refs > 0 then
    table.insert(report_lines, "## ⚠️ Invalid or Suspicious References")
    table.insert(report_lines, "")
    
    for _, ref in ipairs(invalid_refs) do
      table.insert(report_lines, string.format("### Reference to %s %s", ref.type == "chapter" and "Chapter" or "Appendix", ref.ref))
      table.insert(report_lines, "")
      table.insert(report_lines, string.format("- **File:** %s", ref.file))
      table.insert(report_lines, string.format("- **Pattern:** `%s`", ref.pattern))
      table.insert(report_lines, string.format("- **Context:** ...%s...", ref.context))
      table.insert(report_lines, "")
      
      if ref.type == "chapter" then
        local num = tonumber(ref.ref)
        if num and (num < 1 or num > 18) then
          table.insert(report_lines, string.format("⚠️ Chapter %d does not exist (valid range: 1-18)", num))
        else
          table.insert(report_lines, "⚠️ Invalid chapter reference")
        end
      elseif ref.type == "appendix" then
        table.insert(report_lines, string.format("⚠️ Appendix %s does not exist (valid: А, Б, В)", ref.ref))
      end
      
      table.insert(report_lines, "")
    end
  end
  
  -- Valid references summary
  if #valid_refs > 0 then
    table.insert(report_lines, "## ✓ Valid References Summary")
    table.insert(report_lines, "")
    
    -- Count by chapter/appendix
    local counts = {}
    for _, ref in ipairs(valid_refs) do
      local key = string.format("%s %s", ref.type, ref.ref)
      counts[key] = (counts[key] or 0) + 1
    end
    
    table.insert(report_lines, "| Reference | Count |")
    table.insert(report_lines, "|-----------|-------|")
    
    for ref, count in pairs(counts) do
      table.insert(report_lines, string.format("| %s | %d |", ref, count))
    end
    
    table.insert(report_lines, "")
  end
  
  -- Recommendations
  table.insert(report_lines, "## Recommendations")
  table.insert(report_lines, "")
  
  if #invalid_refs > 0 then
    table.insert(report_lines, "1. **Fix invalid references immediately**")
    table.insert(report_lines, "2. Check if chapter/appendix numbers are correct")
    table.insert(report_lines, "3. Verify that referenced content actually discusses the topic")
  else
    table.insert(report_lines, "✓ All references appear valid")
    table.insert(report_lines, "")
    table.insert(report_lines, "Manual verification recommended:")
    table.insert(report_lines, "- Check if referenced chapters actually contain the mentioned content")
    table.insert(report_lines, "- Verify cross-references make sense in context")
  end
  
  table.insert(report_lines, "")
  
  -- Write report
  local report_content = table.concat(report_lines, "\n")
  local report_file = io.open("_cross_references_report.md", "w")
  if report_file then
    report_file:write(report_content)
    report_file:close()
    print(string.format("→ Cross-references report written to _cross_references_report.md (%d total, %d invalid)", 
      #references_found, #invalid_refs))
  end
  
  return doc
end

-- Return filter
return {
  {
    Str = check_str,
    Para = check_para
  },
  {
    Pandoc = generate_report
  }
}

