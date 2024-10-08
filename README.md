# UnityEditor.nvim

<details>

<summary>WIP</summary>

## Progress

- [ ] Add documentation and configuration options.
- [ ] Open script in Neovim
  - Windows: Only works with default Neovim server settings. ([see](https://github.com/hat0uma/UnityEditor.nvim/blob/main/Packages/com.hat0uma.ide.neovim/Editor/NeovimCommand.cs#L19))
  - linux, macOS: Not implemented yet.
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
https://github.com/hat0uma/UnityEditor.nvim.git?path=nvim.Unity/Assets/Neovim
```

2. Neovim Plugin

Install the plugin using your favorite package manager.

lazy.nvim

```lua
{
  'hat0uma/UnityEditor.nvim',
  config = function()
    require('unity-editor').setup()
  end,
  ft = {'cs'}
}
```

</details>
