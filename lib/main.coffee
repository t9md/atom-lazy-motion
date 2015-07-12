{CompositeDisposable, Range, TextEditor} = require 'atom'

{filter} = require 'fuzzaldrin'
_ = require 'underscore-plus'
Match = null
CandidateProvider = null

Config =
  autoLand:
    order:   0
    type:    'boolean'
    default: false
    description: "automatically land(confirm) if only one match exists"
  minimumInputLength:
    order:   1
    type:    'integer'
    minimum: 0
    default: 0
    description: "Search start only when input length exceeds this value"

module.exports =
  subscriptions: null
  config: Config
  candidates: null
  wordPattern: /[@\w-.():]+/g

  activate: ->
    Match = require './match'
    CandidateProvider = require './candidate-provider'
    @searchHistory = []
    @subscriptions = subs = new CompositeDisposable
    subs.add atom.commands.add 'atom-text-editor',
      'rapid-motion:forward':  => @start 'forward'
      'rapid-motion:backward': => @start 'backward'
      'rapid-motion:dump': => @dump()

    @providerByEditor = new WeakMap
    subs.add @observeTextEditors()

    # @subscriptions.add @observeActivePaneItem()
    # @editorSubscriptions = {}
    #   atom.workspace.observeTextEditors (editor) =>
    # @editorSubscriptions[editor.id] = new CompositeDisposable
    # @editorSubscriptions[editor.id].add onDidStopChanging(editor)
    # @editorSubscriptions[editor.id].add onDidDestroy(editor)
    # onDidDestroy = (editor) =>
    #   editor.onDidDestroy =>
    #     @editorSubscriptions[editor.id]?.dispose()
    #     delete @editorSubscriptions[editor.id]

  observeTextEditors: ->
    atom.workspace.observeTextEditors (editor) =>
      return if editor.isMini() or @providerByEditor.get(editor)
      candidateProvider = new CandidateProvider(editor, @wordPattern)
      @providerByEditor.set(editor, candidateProvider)

  # observeActivePaneItem: ->
  #   editor = null
  #   onDidSaved = =>
  #     @buildCandidates()
  #
  #   # Borrow from auto-complet-plus code.
  #   onWillChange = ({oldRange}) =>
  #     range = [[oldRange.start.row, 0], [oldRange.end.row, Infinity]]
  #     @removeCandidatesForRange range
  #
  #   onDidChange = ({newRange}) =>
  #     range = [[newRange.start.row, 0], [newRange.end.row, Infinity]]
  #     @addCandidatesForRange range
    # atom.workspace.observeActivePaneItem (item) =>
    #   return unless item instanceof TextEditor
    #   buffer = item.getBuffer()
    #   editor = item
    #   @editorSubscriptions[item.id] = new CompositeDisposable
    #   @editorSubscriptions[item.id].add buffer.onDidSave(onDidSave)
    #   @editorSubscriptions[item.id].add buffer.onWillChange(onWillChange)
    #   @editorSubscriptions[item.id].add buffer.onDidChange(onDiChange)

  deactivate: ->
    @flashingTimeout = null
    @searchHistory = null
    @subscriptions.dispose()
    @cancel()

  start: (direction) ->
    ui = @getUI()
    unless ui.isVisible()
      @matchForCursor = null
      @editor = atom.workspace.getActiveTextEditor()
      @saveEditorState()
      @reset()
      ui.setDirection direction
      ui.focus()
    else
      ui.setDirection direction
      return unless @matches.length
      @updateCurrent @matches[@updateIndex(direction)]
      ui.refresh()

  # debouncedBuildCandidates: ->
  #   clearTimeout(@buildCandidatesTimeout)
  #   @buildCandidatesTimeout = setTimeout =>
  #     @buildCandidates()
  #   , 300

  search: (direction, text) ->
    # [TODO] move to ovserveTextEditors

    @candidateProvider ?= @providerByEditor.get(@editor)
    candidates = @candidateProvider.getCandidates()

    # initial decoration to unmatch
    for match in @matches ? []
      match.decorate 'rapid-motion-unmatch'

    @matches = []
    return unless text

    @matches = filter candidates, text, key: 'matchText'
    unless @matches.length
      @restoreEditorState()
      @debounceFlashScreen()
      return

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
    @restoreEditorState()
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
    @candidateProvider.resetCandidates() if @candidateProvider?
    @candidateProvider = null
    @matches = []

  getUI: ->
    @ui ?= (
      ui = new (require './ui')
      ui.initialize this
      ui)

  # Accessed from UI
  # -------------------------
  getCount: ->
    if 0 <= @index < @matches.length
      { total: @matches.length, current: @index+1 }
    else
      { total: @matches.length, current: 0 }

  # Utility
  # -------------------------
  debounceFlashScreen: ->
    @_debounceFlashScreen ?= _.debounce =>
      @flashScreen()
    , 150, true
    @_debounceFlashScreen()

  flashScreen: ->
    [startRow, endRow] = @editor.getVisibleRowRange()
    range = new Range([startRow, 0], [endRow, Infinity])
    marker = @editor.markBufferRange range,
      invalidate: 'never'
      persistent: false

    @flashingDecoration?.getMarker().destroy()
    clearTimeout @flashingTimeout

    @flashingDecoration = @editor.decorateMarker marker,
      type: 'highlight'
      class: 'rapid-motion-flash'

    @flashingTimeout = setTimeout =>
      @flashingDecoration.getMarker().destroy()
      @flashingDecoration = null
    , 150

  dump: ->
    console.log @candidates?.map (m) -> m.matchText

  saveEditorState: ->
    @editorState = {scrollTop: @editor.getScrollTop()}

  restoreEditorState: ->
    @editor.setScrollTop @editorState.scrollTop if @editorState?
