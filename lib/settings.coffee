ConfigPlus = require 'atom-config-plus'

module.exports = new ConfigPlus 'lazy-motion',
  autoLand:
    order:   0
    type:    'boolean'
    default: false
    description: "automatically land(confirm) if there is no other candidates"
  minimumInputLength:
    order:   1
    type:    'integer'
    minimum: 0
    default: 0
    description: "Search start only when input length exceeds this value"
  wordRegExp:
    order:   2
    type:    'string'
    default: '[@\\w-.():?]+'
    description: "Used to build candidate List"
  showHoverIndicator:
    order:   3
    type:    'boolean'
    default: true
  historySize:
    order:   4
    type:    'integer'
    minimum: 0
    default: 30
  saveHistoryOnCancel:
    order:   5
    type:    'boolean'
    default: true
    description: "If false, canceled search won't saved to history."
