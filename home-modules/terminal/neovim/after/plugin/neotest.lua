require('neotest').setup {
  adapters = {
    require('rustaceanvim.neotest')
  },
  consumers = {
    overseer = require("neotest.consumers.overseer"),
  },
}
