--[[
Check Terminology Filter for Quarto Book Pipeline
Purpose: Check consistency of terminology usage across the book

Usage:
  Add to _quarto.yml:
    filters:
      - check-terminology.lua

This filter will:
1. Scan text for terminology variations
2. Check against preferred forms
3. Generate a report with inconsistencies
4. Output: _terminology_report.md
--]]

-- Preferred terminology forms
local preferred_terms = {
  -- Core DevRel terms
  ["Developer Relations"] = {
    preferred = "Developer Relations (DevRel) при первом упоминании, затем DevRel",
    variations = {"developer relations", "DeveloperRelations"},
    first_mention_full = true
  },
  ["DevRel"] = {
    preferred = "DevRel (после первого упоминания Developer Relations)",
    variations = {"devrel", "dev-rel"},
    first_mention_full = false
  },
  
  -- Abbreviations
  ["eNPS"] = {
    preferred = "eNPS (Employee Net Promoter Score при первом упоминании)",
    variations = {"Employee NPS", "ENPS", "enps"},
    first_mention_full = true
  },
  ["ROI"] = {
    preferred = "ROI (Return on Investment при первом упоминании)",
    variations = {"roi", "R.O.I."},
    first_mention_full = true
  },
  ["API"] = {
    preferred = "API (Application Programming Interface при первом упоминании)",
    variations = {"api", "A.P.I."},
    first_mention_full = true
  },
  ["SDK"] = {
    preferred = "SDK (Software Development Kit при первом упоминании)",
    variations = {"sdk", "S.D.K."},
    first_mention_full = true
  },
  
  -- Russian vs English
  ["митап"] = {
    preferred = "митап (не meetup)",
    variations = {"meetup", "Meetup", "митап-встреча"},
    use_russian = true
  },
  ["хакатон"] = {
    preferred = "хакатон (не hackathon)",
    variations = {"hackathon", "Hackathon"},
    use_russian = true
  },
  
  -- Employer Brand
  ["бренд работодателя"] = {
    preferred = "бренд работодателя или Employer Brand",
    variations = {"employer brand", "работодательский бренд"},
    both_forms_ok = true
  },
}

-- Global state for tracking issues
local issues = {}
local current_file = "unknown"

-- Helper: check if string matches any variation
local function check_variations(text, term_data)
  local lower_text = text:lower()
  
  for _, variation in ipairs(term_data.variations or {}) do
    if lower_text == variation:lower() then
      return true, variation
    end
  end
  
  return false, nil
end

-- Process Str elements
local function check_str(elem)
  local text = elem.text
  
  -- Check each preferred term
  for term, data in pairs(preferred_terms) do
    local found, variation = check_variations(text, data)
    
    if found then
      table.insert(issues, {
        term = term,
        found_variation = variation,
        preferred = data.preferred,
        file = current_file,
        context = text
      })
    end
  end
  
  return elem
end

-- Generate report at the end
local function generate_report(doc)
  if #issues == 0 then
    print("✓ Terminology check: no issues found")
    return doc
  end
  
  -- Group issues by term
  local grouped = {}
  for _, issue in ipairs(issues) do
    if not grouped[issue.term] then
      grouped[issue.term] = {}
    end
    table.insert(grouped[issue.term], issue)
  end
  
  -- Build report
  local report_lines = {
    "# Terminology Report",
    "",
    string.format("Found %d terminology inconsistencies.", #issues),
    "",
    "## Issues by Term",
    ""
  }
  
  for term, term_issues in pairs(grouped) do
    table.insert(report_lines, string.format("### %s", term))
    table.insert(report_lines, "")
    table.insert(report_lines, string.format("**Preferred:** %s", term_issues[1].preferred))
    table.insert(report_lines, "")
    table.insert(report_lines, string.format("**Found %d variations:**", #term_issues))
    table.insert(report_lines, "")
    
    for _, issue in ipairs(term_issues) do
      table.insert(report_lines, string.format("- `%s` (file: %s)", issue.found_variation, issue.file))
    end
    
    table.insert(report_lines, "")
  end
  
  -- Recommendations
  table.insert(report_lines, "## Recommendations")
  table.insert(report_lines, "")
  table.insert(report_lines, "1. Review each inconsistency")
  table.insert(report_lines, "2. Update to preferred form")
  table.insert(report_lines, "3. For first mentions, use full form with abbreviation")
  table.insert(report_lines, "4. Be consistent throughout the book")
  table.insert(report_lines, "")
  
  -- Write report
  local report_content = table.concat(report_lines, "\n")
  local report_file = io.open("_terminology_report.md", "w")
  if report_file then
    report_file:write(report_content)
    report_file:close()
    print(string.format("→ Terminology report written to _terminology_report.md (%d issues)", #issues))
  end
  
  return doc
end

-- Return filter
return {
  {
    Str = check_str
  },
  {
    Pandoc = generate_report
  }
}

