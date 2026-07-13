local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local FORMATTING = methods.internal.FORMATTING

return h.make_builtin({
    name = "ryl_format",
    meta = {
        url = "https://github.com/owenlamont/ryl",
        description = "Fast YAML linter and formatter written in Rust",
    },
    method = FORMATTING,
    filetypes = { "yaml" },
    generator_opts = {
        command = "ryl",
        args = { "check", "--fix", "$FILENAME" },
        to_temp_file = true,
        from_temp_file = true,
    },
    factory = h.formatter_factory,
})
