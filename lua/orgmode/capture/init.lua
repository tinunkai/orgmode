local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Files = require('orgmode.parser.files')
local Templates = require('orgmode.capture.templates')
vim.cmd([[augroup OrgCapture]])
vim.cmd([[autocmd!]])
vim.cmd([[augroup END]])

---@class Capture
---@field templates Templates
local Capture = {}

function Capture:new()
  local data = {}
  data.templates = Templates:new()
  setmetatable(data, self)
  self.__index = self
  return data
end

function Capture:_get_subtemplates(base_key, templates)
  local subtemplates = {}
  for key, template in pairs(templates) do
    if string.len(key) > 1 and string.sub(key, 1, 1) == base_key then
      subtemplates[string.sub(key, 2, string.len(key))] = template
    end
  end
  return subtemplates
end

function Capture:_create_menu_items(templates)
  local menu_items = {}
  for key, template in pairs(templates) do
    if string.len(key) == 1 then
      local item = {
        key = key,
      }
      if type(template) == 'string' then
        item['label'] = template .. '...'
        item['action'] = function()
          self:_create_prompt(self:_get_subtemplates(key, templates))
        end
      else
        item['label'] = template.description
        item['action'] = function()
          return self:open_template(template)
        end
      end
      table.insert(menu_items, item)
    end
  end
  return menu_items
end

function Capture:_create_prompt(templates)
  local menu_items = self:_create_menu_items(templates)
  table.insert(menu_items, { label = '', key = '', separator = '-' })
  table.insert(menu_items, { label = 'Quit', key = 'q' })
  table.insert(menu_items, { label = '', separator = ' ', length = 1 })

  return utils.menu('Select a capture template', menu_items, 'Template key')
end

function Capture:prompt()
  self:_create_prompt(self.templates:get_list())
end

---@param template table
function Capture:open_template(template)
  local content = self.templates:compile(template)
  vim.cmd('16split ' .. vim.fn.tempname())
  vim.cmd([[setf org]])
  vim.cmd([[setlocal bufhidden=wipe nobuflisted nolist noswapfile nofoldenable]])
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  self.templates:setup()
  vim.api.nvim_buf_set_var(0, 'org_template', template)
  vim.api.nvim_buf_set_var(0, 'org_capture', true)
  config:setup_mappings('capture')
  vim.cmd([[autocmd OrgCapture BufWipeout <buffer> ++once lua require('orgmode').action('capture.refile', true)]])
end

---@param shortcut string
function Capture:open_template_by_shortcut(shortcut)
  local template = self.templates:get_list()[shortcut]
  if not template then
    return utils.echo_error('No capture template with shortcut ' .. shortcut)
  end
  return self:open_template(template)
end

---Triggered when refiling from capture buffer
---@param confirm? boolean
function Capture:refile(confirm)
  local is_modified = vim.bo.modified
  local template = vim.api.nvim_buf_get_var(0, 'org_template') or {}
  local file = vim.fn.fnamemodify(template.target or config.org_default_notes_file, ':p')
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local headline_title = template.headline
  if confirm and is_modified then
    local choice = vim.fn.confirm(string.format('Do you want to refile this to %s?', file), '&Yes\n&No')
    vim.cmd([[redraw!]])
    if choice ~= 1 then
      return utils.echo_info('Canceled.')
    end
  end
  vim.defer_fn(function()
    -- TODO: Parse refile content as org file and update refile destination to point to headline or root
    if headline_title then
      self:refile_to_headline(file, lines, nil, headline_title)
    else
      self:_refile_to_end(file, lines)
    end
    vim.cmd([[autocmd! OrgCapture BufWipeout <buffer>]])
    vim.cmd([[silent! wq]])
  end, 0)
end

---Triggered when refiling to destination from capture buffer
function Capture:refile_to_destination()
  local template = vim.api.nvim_buf_get_var(0, 'org_template')
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local default_file = vim.fn.fnamemodify(template.target or config.org_default_notes_file, ':p')
  -- TODO: Parse refile content as org file and update refile destination to point to headline or root
  self:_refile_content_with_fallback(lines, default_file)
  vim.cmd([[autocmd! OrgCapture BufWipeout <buffer>]])
  vim.cmd([[silent! wq]])
end

---Triggered from org file when we want to refile headline
function Capture:refile_headline_to_destination()
  local agenda_file = Files.get_current_file()
  local item = agenda_file:get_closest_headline()
  local lines = agenda_file:get_headline_lines(item)
  return self:_refile_content_with_fallback(lines, nil, item)
end

---@param file Root
---@param item string
---@param archive_file string
---@return string
function Capture:refile_file_headline_to_archive(file, item, archive_file)
  local lines = file:get_headline_lines(item)
  return self:_refile_to_end(archive_file, lines, item, string.format('Archived to %s', archive_file))
end

---@param file string
---@param lines string[]
---@param item? Section
---@param message? string
---@return boolean
function Capture:_refile_to_end(file, lines, item, message)
  local refiled = self:_refile_to(file, lines, item, '$')
  if not refiled then
    return false
  end
  utils.echo_info(message or string.format('Wrote %s', file))
  return true
end

---@param lines string[]
---@param fallback_file string
---@param item? Section
---@return string
function Capture:_refile_content_with_fallback(lines, fallback_file, item)
  local default_file = fallback_file and fallback_file ~= '' and vim.fn.fnamemodify(fallback_file, ':p') or nil

  local valid_destinations = {}
  for _, file in ipairs(Files.filenames()) do
    valid_destinations[vim.fn.fnamemodify(file, ':t')] = file
  end

  local destination = vim.fn.OrgmodeInput('Enter destination: ', '', self.autocomplete_refile)
  destination = vim.split(destination, '/', true)

  if not valid_destinations[destination[1]] then
    return self:_refile_to_end(default_file, lines, item)
  end

  local destination_file = valid_destinations[destination[1]]
  if not destination[2] or destination[2] == '' then
    return self:_refile_to_end(destination_file, lines, item)
  end
  return self:refile_to_headline(destination_file, lines, item, destination[2])
end

function Capture:refile_to_headline(destination_file, lines, item, headline_title)
  local agenda_file = Files.get(destination_file)
  local headline
  if headline_title then
    headline = agenda_file:find_headline_by_title(headline_title)
  end

  if not headline then
    return self._refile_to_end(destination_file, lines, item)
  end

  if item and item.level <= headline.level then
    -- Refiling in same file just moves the lines from one position
    -- to another,so we need to apply demote instantly
    local is_same_file = agenda_file.filename == item.root.filename
    lines = item:demote(headline.level - item.level + 1, true, not is_same_file)
  end
  local refiled = self:_refile_to(destination_file, lines, item, headline.range.end_line)
  if not refiled then
    return false
  end
  utils.echo_info(string.format('Wrote %s', destination_file))
  return true
end

---@param file string
---@param lines string[]
---@param item? Section
---@param destination_line string|number
---@return boolean
function Capture:_refile_to(file, lines, item, destination_line)
  if not file then
    return false
  end

  local is_same_file = file == vim.api.nvim_buf_get_name(0)
  local cur_win = vim.api.nvim_get_current_win()

  if is_same_file and item then
    vim.cmd(
      string.format('silent! %d,%d move %s', item.range.start_line, item.range.end_line, tostring(destination_line))
    )
    return true
  end

  if not is_same_file then
    local bufnr = vim.fn.bufadd(file)
    vim.api.nvim_open_win(bufnr, true, {
      relative = 'editor',
      width = 1,
      height = 1,
      row = 99999,
      col = 99999,
      zindex = 1,
      style = 'minimal',
    })
  end

  vim.fn.append(destination_line, lines)

  if not is_same_file then
    vim.cmd('silent! wq!')
    vim.api.nvim_set_current_win(cur_win)
  end

  if item then
    vim.cmd(string.format('silent! %d,%d delete', item.range.start_line, item.range.end_line))
  end

  return true
end

---@param arg_lead string
---@return string[]
function Capture.autocomplete_refile(arg_lead)
  local valid_filenames = {}
  for _, filename in ipairs(Files.filenames()) do
    valid_filenames[vim.fn.fnamemodify(filename, ':t') .. '/'] = filename
  end

  if not arg_lead then
    return vim.tbl_keys(valid_filenames)
  end
  local parts = vim.split(arg_lead, '/', true)

  local selected_file = valid_filenames[parts[1] .. '/']

  if not selected_file then
    return vim.tbl_filter(function(file)
      return file:match('^' .. vim.pesc(parts[1]))
    end, vim.tbl_keys(valid_filenames))
  end

  local agenda_file = Files.get(selected_file)
  if not agenda_file then
    return {}
  end

  local headlines = agenda_file:get_opened_unfinished_headlines()
  local result = vim.tbl_map(function(headline)
    return string.format('%s/%s', vim.fn.fnamemodify(headline.file, ':t'), headline.title)
  end, headlines)

  return vim.tbl_filter(function(item)
    return item:match(string.format('^%s', vim.pesc(arg_lead)))
  end, result)
end

function Capture:kill()
  vim.cmd([[autocmd! OrgCapture BufWipeout <buffer>]])
  vim.api.nvim_win_close(0, true)
end

return Capture
