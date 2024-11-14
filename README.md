# Kusho

<a href="https://dotfyle.com/plugins/h-tiwari-kusho/api-test-generator">
	<img src="https://dotfyle.com/plugins/h-tiwari-kusho/api-test-generator/shield?style=flat" />
</a>


A Neovim plugin for HTTP request management, test generation, and API testing with Telescope integration.

## Features

- 🚀 Parse and execute HTTP requests directly from your editor
- 🧪 Automatic test generation for API endpoints
- 🔍 Telescope integration for browsing test suites
- 📝 Detailed request/response logging
- 💻 Interactive status window for request processing
- 🎨 Clean UI for response visualization
- 🔄 Support for streaming responses
- 📊 Request history tracking

## Prerequisites

- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for test suite browsing)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'h-tiwari-kusho/api-test-generator',
    dependencies = {
        'nvim-lua/plenary.nvim',
        {
            'nvim-telescope/telescope.nvim',
            event = 'VimEnter',
            branch = '0.1.x',
            dependencies = {
                'nvim-lua/plenary.nvim',
                {
                    'nvim-telescope/telescope-fzf-native.nvim',
                    build = 'make',
                    cond = function()
                        return vim.fn.executable 'make' == 1
                    end,
                },
                { 'nvim-telescope/telescope-ui-select.nvim' },
                { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
            },
        }
    },
    config = function()
        -- Setup kusho with default configuration
        require('kusho').setup({
            -- Optional configuration
            api = {
                save_directory = vim.fn.stdpath("data") .. "/kusho/test-suites",
            },
        })

        -- Telescope Configuration
        require('telescope').setup({
            extensions = {
                ['ui-select'] = {
                    require('telescope.themes').get_dropdown(),
                },
                kusho = {
                    -- Kusho specific telescope configuration
                    mappings = {
                        copy_to_clipboard = '<C-y>', -- Custom mapping to copy request
                    }
                }
            },
        })

        -- Enable telescope extensions
        pcall(require('telescope').load_extension, 'fzf')
        pcall(require('telescope').load_extension, 'ui-select')
        pcall(require('telescope').load_extension, 'kusho')
    end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'h-tiwari-kusho/api-test-generator',
    requires = {
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
    },
    config = function()
        require('kusho').setup({
            -- configuration options
        })
    end
}
```

## Configuration

```lua
require('kusho').setup({
    -- Optional configuration
    api = {
        save_directory = vim.fn.stdpath("data") .. "/kusho/test-suites", -- Directory to save test suites
    },
    log = {
        level = "debug", -- Log level (debug, info, warn, error)
        use_console = "async", -- Log to console
        use_file = true -- Save logs to file
    }
})
```

## Keymaps

Recommended keymaps for Kusho with Telescope integration:

```lua
-- Basic Kusho commands
vim.keymap.set('n', '<leader>kr', '<cmd>KushoRunRequest<cr>', { desc = '[K]usho [R]un Request' })
vim.keymap.set('n', '<leader>kt', '<cmd>KushoCreateTests<cr>', { desc = '[K]usho Create [T]ests' })
vim.keymap.set('n', '<leader>kl', '<cmd>KushoOpenLatest<cr>', { desc = '[K]usho Open [L]atest' })

-- Telescope integration
vim.keymap.set('n', '<leader>ks', '<cmd>Telescope kusho<cr>', { desc = '[K]usho [S]earch Test Suites' })

-- Additional Telescope keymaps for file searching
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
```

## Commands

| Command | Description |
|---------|-------------|
| `:ParseHttpRequest` | Parse HTTP request at cursor position |
| `:KushoCreateTests` | Generate tests for current request |
| `:KushoRunRequest` | Execute the HTTP request at cursor position |
| `:KushoLogRequests` | Show all stored requests |
| `:KushoShowLogs` | Display plugin logs |
| `:KushoClearLogs` | Clear plugin logs |
| `:KushoVersion` | Show plugin version |

## Telescope Integration

After installation, you can use the Telescope integration to browse and manage your test suites:

```vim
:Telescope kusho
```

This will open a Telescope picker showing all your generated test suites with a preview of the original request.

Default Telescope picker keymaps:
- `<CR>`: Open selected test suite
- `<C-y>`: Copy request to clipboard (configurable)
- `<C-u>/<C-d>`: Scroll preview up/down
- `?`: Show help menu

## HTTP Request Format

Kusho supports standard HTTP request format:

```http
POST https://api.example.com/endpoint
Content-Type: application/json
Authorization: Bearer your-token

{
    "key": "value"
}
```

## Test Generation

When generating tests, Kusho creates a structured directory for each request:

```
~/.local/share/nvim/kusho/test-suites/
└── <request-hash>/
    ├── test_cases.http
    └── response.tmp
```

Generated tests include:
- Original request
- Test metadata (description, categories, types)
- Modified requests for different scenarios

## API Response Display

Responses are displayed in a new buffer with:
- Status code
- Headers
- Formatted JSON body (if applicable)
- Syntax highlighting

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

## Acknowledgments

- Built with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Telescope integration powered by [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Troubleshooting

### Common Issues

1. **No HTTP request found at cursor position**
   - Ensure your cursor is positioned within a valid HTTP request block
   - Verify the request format matches the expected syntax

2. **API request failed**
   - Check your authentication token if required
   - Verify the API endpoint is accessible
   - Review the logs using `:KushoShowLogs`

3. **Test generation fails**
   - Ensure you have write permissions to the save directory
   - Check the connection to the test generation service
   - Review the status window for error messages

4. **Telescope integration not working**
   - Verify telescope.nvim is properly installed and configured
   - Check if the extension is loaded with `:Telescope extensions`
   - Ensure all dependencies are installed

### Logging

To enable detailed logging:

```lua
require('kusho').setup({
    log = {
        level = "debug",
        use_console = "async",
        use_file = true
    }
})
```

Logs can be viewed with `:KushoShowLogs` or found in:
```
~/.cache/nvim/kusho.log
```
