local PROMPT_LINUX = "find /usr/lib/jvm -name 'javac' 2>/dev/null"
local PROMPT_WINDOWS =
"powershell -NoProfile -ExecutionPolicy Bypass -Command \"(Get-ChildItem -Path 'C:/Program Files*' -Filter 'javac.exe' -Recurse -ErrorAction SilentlyContinue).DirectoryName\""

local function get_runtimes()
  local runtimes = {}

  local command = PROMPT_LINUX
  if vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 or vim.fn.has("win16") == 1 then
    command = PROMPT_WINDOWS
  end

  local handle, error = io.popen(command, "r")
  if handle then
    local result = handle:read("*a")
    handle:close()

    for line in string.gmatch(result, "([^\n]+)") do
      local version = string.match(line, "%d+")
      if not version then
        return
      end

      version = tonumber(version)
      if version < 9 then
        if version < 6 then
          version = "J2SE-1." .. version
        else
          version = "JavaSE-1." .. version
        end
      else
        version = "JavaSE-" .. version
      end

      local offset = 10
      if vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 or vim.fn.has("win16") == 1 then
        offset = 3
      end

      table.insert(runtimes, {
        name = version,
        path = string.sub(line, 0, #line - offset),
      })
    end
  else
    print("Failed to find java! [" .. error .. "")
  end

  return runtimes
end

local function configure_jdtls()
  -- location of `jdtls` package
  local jdtls_path = vim.fn.expand("$MASON/packages/jdtls")
  local jdebug_adapter = vim.fn.expand("$MASON/packages/java-debug-adapter")

  -- configuration
  local config = jdtls_path .. "/config_"
  if vim.fn.has("unix") then
    config = config .. "linux"

    -- ❯ find /usr/lib/jvm -name 'javac' 2>/dev/null
  elseif vim.fn.has("mac") then
    config = config .. "mac"
  elseif vim.fn.has("win32") or vim.fn.has("win64") then
    config = config .. "win"
  end

  return vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar"),
      config,
      jdtls_path .. "/lombok.jar",
      jdtls_path .. "/workspace/",
      vim.fn.glob(jdebug_adapter .. "/extension/server/com.microsoft.java.debug.plugin-*.jar", 1)
end

local function get_jdtls_config()
  -- used for accessing capabilities
  local lsp = require("cmp_nvim_lsp")

  -- get all the things needed for the configuration to work
  local launcher, configuration, lombok, workspace, jdebug = configure_jdtls()

  -- fet the default extended client capablities of the JDTLS language server
  local extendedClientCapabilities = lsp.default_capabilities()
  extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

  return {
    cmd = {
      "java",
      "-Declipse.application=org.eclipse.jdt.ls.core.id1",
      "-Dosgi.bundles.defaultStartLevel=4",
      "-Declipse.product=org.eclipse.jdt.ls.core.product",
      "-Dlog.protocol=true",
      "-Dlog.level=ALL",
      "-Xmx1g",
      "--add-modules=ALL-SYSTEM",
      "--add-opens",
      "java.base/java.util=ALL-UNNAMED",
      "--add-opens",
      "java.base/java.lang=ALL-UNNAMED",
      "-javaagent:" .. lombok,
      "-jar",
      launcher,
      "-configuration",
      configuration,
      "-data",
      workspace .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t"),
    },
    root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", "build.gradle", "pom.xml" }),
    settings = {
      java = {
        import = {
          enabled = true,
        },
        format = {
          enabled = true,
          settings = {
            url = vim.fn.getcwd() .. "/code-style.xml",
            profile = "GoogleStyle",
          },
        },
        eclipse = { downloadSource = true },
        maven = { downloadSources = true },
        signatureHelp = { enabled = true },
        contentProvider = { preferred = "fernflower" },
        configuration = {
          updateBuildConfiguration = "interactive",
          runtimes = get_runtimes(),
        },
        referencesCodeLens = { enabled = true },
        inlayHints = {
          parameterNames = {
            enabled = "all",
          },
        },
      },
    },
    capabilities = lsp.default_capabilities(),
    init_options = {
      extendedClientCapabilities = extendedClientCapabilities,
      bundles = {
        jdebug,
      },
      settings = {
        java = {
          implementationsCodeLens = { enabled = true },
        },
      },
    },
    on_attach = function(_, _)
      -- enable jdtls commands to be used in neovim
      require("jdtls.setup").add_commands()

      -- custom keybinds
      vim.keymap.set("n", "<leader>jrl", ":JdtUpdateConfig<CR>", { desc = "Updates JDTLS project configuration" })
      vim.keymap.set(
        "n",
        "<leader>jbc",
        ":JdtBytecode<CR>",
        { desc = "Shows bytecode of the currently open buffer" }
      )

      -- code lens enables features such as code reference counts, implemenation counts, and more.
      vim.lsp.codelens.refresh()

      -- setup a function that automatically runs every time a java file is saved to refresh the code lens
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = { "*.java" },
        callback = function()
          local _, _ = pcall(vim.lsp.codelens.refresh)
        end,
      })
    end,
  }
end

return { get_jdtls_config = get_jdtls_config }
