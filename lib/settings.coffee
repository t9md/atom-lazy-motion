ConfigPlus = require 'atom-config-plus'

module.exports = new ConfigPlus 'rapid-motion',
  useWildChar:
    order:   0
    type:    'boolean'
    default: true
  wildChar:
    order:   1
    type:    'string'
    default: ''
    description: "Use this char as wild card char"
