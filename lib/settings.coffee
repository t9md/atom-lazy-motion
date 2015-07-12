ConfigPlus = require 'atom-config-plus'

module.exports = new ConfigPlus 'rapid-motion',
  autoLand:
    order:   0
    type:    'boolean'
    default: false
    description: "automatically land(confirm) if only one match exists"
