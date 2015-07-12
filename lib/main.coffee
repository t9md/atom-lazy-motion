{CompositeDisposable, Range} = require 'atom'

{filter} = require 'fuzzaldrin'
_ = require 'underscore-plus'

Match = null
Config =
  autoLand:
    order:   0
    type:    'boolean'
    default: false
    description: "automatically land(confirm) if only one match exists"
  # visitOrder:
  #   order: 1
  #   type: 'string'
  #   default: 'position'
  #   enum: ['position', 'score']
  #   description: "If you chose score, higher fuzzaldrin score comes first"

module.exports =
  subscriptions: null
  config: Config
  candidates: null

  activate: ->
    Match = require './match'
    @searchHistory = []
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'rapid-motion:forward':  => @start 'forward'
      'rapid-motion:backward': => @start 'backward'

  deactivate: ->
    @searchHistory = null
    @subscriptions.dispose()
    @cancel()

  start: (direction) ->
    ui = @getUI()
    unless ui.isVisible()
      @init()
      @reset()
      ui.setDirection direction
      ui.focus()
    else
      ui.setDirection direction
      return unless @matches.length
      @updateCurrent @matches[@updateIndex(direction)]
      ui.refresh()

  # visit: (direction) ->

  init: ->
    @matchForCursor = null
    @editor = atom.workspace.getActiveTextEditor()
    @editorState = @getEditorState @editor

  getCandidates: ->
    pattern = /[\w-.]+/g
    @scan(@editor, pattern)

  scan: (editor, pattern) ->
    matches = []
    editor.scan pattern, ({range, matchText}) =>
      matches.push new Match(editor, {range, matchText, class: 'rapid-motion-unmatch'})
    matches

  search: (direction, text) ->
    # [TODO] move to ovserveTextEditors
    @candidates ?= @getCandidates()
    for match in @matches ? []
      # initial decoration to unmatch
      match.decorate 'rapid-motion-unmatch'

    @matches = []
    return unless text

    @matches = filter @candidates, text, key: 'matchText'
    return unless @matches.length

    if @matches.length is 1 and atom.config.get('rapid-motion.autoLand')
      @index = 0
      @getUI().confirm()
      return

    for match in @matches
      match.decorate 'rapid-motion-match'

    @matchForCursor ?= @getMatchForCursor()

    @matches = _.sortBy @matches, (match) ->
      match.getScore()
    @index = _.sortedIndex @matches, @matchForCursor, (match) ->
      match.getScore()

    # Decorate Top and Bottom match differently
    @matches[0].decorate 'rapid-motion-match top'
    if @matches.length > 1
      @matches[@matches.length-1].decorate 'rapid-motion-match bottom'

    # @index can be 0 - N
    # Adjusting @index here to adapt to modification by @updateIndex().
    if direction is 'forward'
      @index -= 1
    @updateCurrent @matches[@updateIndex(direction)]

  updateCurrent: (match) ->
    @lastCurrent?.decorate 'current', 'remove'
    match.decorate 'current', 'append'
    match.flash()
    match.scroll()
    @lastCurrent = match

  updateIndex: (direction) ->
    if direction is 'forward'
      @index += 1
      if @index is @matches.length
        @index = 0
    else if direction is 'backward'
      @index -= 1
      if @index is -1
        @index = @matches.length - 1
    @index

  getMatchForCursor: ->
    start = @editor.getCursorBufferPosition()
    end = start.translate([0, 1])
    range = new Range(start, end)
    match = new Match(@editor, {range})
    match.decorate 'rapid-motion-cursor'
    match

  cancel: ->
    @setEditorState @editor, @editorState if @editorState?
    @editorState = null
    @matchForCursor?.destroy()
    @matchForCursor = null
    @lastCurrent = null
    @reset()

  land: ->
    @matches?[@index]?.land()
    @matchForCursor?.destroy()
    @matchForCursor = null
    @reset()

  reset: ->
    @index = 0
    # _.defer =>
    for match in @candidates ? []
      match.destroy()
    @candidates = null
    @matches = []

  getUI: ->
    @ui ?= (
      ui = new (require './ui')
      ui.initialize this
      ui)

  # Accessed from UI
  # -------------------------
  getCount: ->
    if 0 < @index < @matches.length
      { total: @matches.length, current: @index+1 }
    else
      { total: @matches.length, current: 0 }

  # Utility
  # -------------------------
  getEditorState: (editor) ->
    scrollTop: editor.getScrollTop()

  setEditorState: (editor, {scrollTop}) ->
    editor.setScrollTop scrollTop
