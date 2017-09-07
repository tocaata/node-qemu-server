os     = require 'os'

sys = {}
sys.totalmem = os.totalmem()
sys.cores    = os.cpus().length / 2

module.exports.settings = sys