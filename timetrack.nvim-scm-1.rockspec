rockspec_format = "3.0"
package = "timetrack.nvim"
version = "scm-1"
source = {
  url = "git://github.com/maorun/timeTrack.nvim.git"
}
description = {
  summary = "A Neovim plugin for tracking time spent on projects.",
  homepage = "https://github.com/maorun/timeTrack.nvim",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
dev_dependencies = {
  "vusted",
  "stylua",
  "luacheck"
}
build = {
  type = "builtin",
  modules = {
    ["maorun.time.init"] = "lua/maorun/time/init.lua",
    ["maorun.time.weekday_select"] = "lua/maorun/time/weekday_select.lua",
    ["plugin.timeTrack"] = "plugin/timeTrack.nvim.lua"
  }
}
