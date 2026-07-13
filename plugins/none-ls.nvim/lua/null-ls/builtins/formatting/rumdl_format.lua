local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local FORMATTING = methods.internal.FORMATTING

return h.make_builtin({
    name = "rumdl_format",
    meta = {
        url = "https://github.com/rvben/rumdl",
        description = "Fast Markdown linter and formatter written in Rust",
    },
    method = FORMATTING,
    filetypes = { "markdown" },
    generator_opts = {
        command = "rumdl",
        args = { "fmt", "--stdin-filename", "$FILENAME", "--stdin" },
        to_stdin = true,
    },
    factory = h.formatter_factory,
})
