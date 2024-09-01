# UnityEditor.nvim

WIP

## Progress

- [ ] Add documentation and configuration options.
- [x] Compile scripts from Neovim.
- [x] Enter/Exit Play Mode from Neovim.
- [x] Generate .sln and .csproj files from Neovim.
- [ ] Debugging support.
- [ ] Run tests from Neovim.

## Installation

Unity Packge and Neovim Plugin are required to use this plugin.

1. Unity Package

`Add package from git URL` in Unity Package Manager.

```text
https://github.com/hat0uma/UnityEditor.nvim.git?path=Packages/com.hat0uma.ide.neovim
```

2. Neovim Plugin

Install the plugin using your favorite package manager.

lazy.nvim

```lua
{
  'hat0uma/UnityEditor.nvim',
  config = function()
    require('unity-editor').setup()
  end
  ft = {'cs'}
}
```
