--- This file is a script to read package information from nvim.Unity/Assets/Neovim/package.json.
--- see https://docs.unity3d.com/2022.3/Documentation/Manual/upm-manifestPkg.html

--- Get the path of the this script.
---@return string
local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end

--- @class UnityEditor.PackageInfo
--- @field name string
--- @field version string
--- @field displayName? string
--- @field description? string
--- @field unity? string
--- @field author? string
--- @field repository? string
--- @field license? string

--- Load package.json from nvim.Unity/Assets/Neovim/package.json.
---@return UnityEditor.PackageInfo? package_info, string? err
local function load_package_json()
  -- path to package.json from current file
  local path = vim.fs.joinpath(script_path(), "../../nvim.Unity/Assets/Neovim/package.json")
  path = vim.fs.normalize(path)

  -- open file
  local f, err
  f, err = vim.uv.fs_open(path, "r", 438)
  if not f then
    return nil, string.format("Failed to open %s: %s", path, err)
  end

  -- get file size
  local stat
  stat, err = vim.uv.fs_fstat(f)
  if not stat then
    vim.uv.fs_close(f)
    return nil, string.format("Failed to stat %s: %s", path, err)
  end

  -- read file
  local text
  text, err = vim.uv.fs_read(f, stat.size, 0)
  vim.uv.fs_close(f)
  if not text then
    return nil, string.format("Failed to read %s: %s", path, err)
  end

  local data = vim.json.decode(text)
  vim.validate({
    data = { data, "table" },
    ["data.name"] = { data.name, "string" },
    ["data.version"] = { data.version, "string", true },
    ["data.displayName"] = { data.displayName, "string", true },
    ["data.description"] = { data.description, "string", true },
    ["data.unity"] = { data.unity, "string", true },
    ["data.author"] = { data.author, "string", true },
    ["data.repository"] = { data.repository, "string", true },
    ["data.license"] = { data.license, "string", true },
  })
  return data
end

---@class UnityEditor.PackageInfo
local package_info

---@type UnityEditor.PackageInfo
local M = setmetatable({}, {
  __index = function(_, key)
    if not package_info then
      package_info = assert(load_package_json())
    end
    return package_info[key]
  end,
})

return M
