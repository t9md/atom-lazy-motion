{CompositeDisposable, Range, TextEditor} = require 'atom'

{filter} = require 'fuzzaldrin'
_ = require 'underscore-plus'
Match = null
CandidateProvider = null
Container = null
Hover = null

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
  wordRegExp:
    order:   2
    type:    'string'
    default: '[@\\w-.():]+'
    description: "Used to build candidate List"
  showHoverIndicator:
    order:   3
    type:    'boolean'
    default: false

module.exports =
  subscriptions: null
  config: Config
  container: null

  activate: ->
    Match = require './match'
    {Container, Hover} = require './hover-indicator'
    CandidateProvider = require './candidate-provider'

    @subscriptions = subs = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'rapid-motion:forward':  => @start 'forward'
      'rapid-motion:backward': => @start 'backward'
      'rapid-motion:dump': => @dump()

  getWordPattern: ->
    pattern  = atom.config.get('rapid-motion.wordRegExp')
    try
      new RegExp(pattern, 'g')
    catch e
      # Auto FIX to default if invalid RegExp.
      atom.config.set('rapid-motion.wordRegExp', Config.wordRegExp.default)
      @getWordPattern()

  deactivate: ->
    @container = null
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
      @index = 0
      @matches = []
      ui.setDirection direction
      ui.focus()
    else
      ui.setDirection direction
      return unless @matches.length
      @updateCurrent @matches[@updateIndex(direction)]
      ui.refresh()

  decorateMatches: (matches, klass) ->
    for m in matches ? []
      m.decorate klass

  getCandidates: ->
    @candidateProvider ?= new CandidateProvider(@editor, @getWordPattern())
    @candidateProvider.getCandidates()

  search: (direction, text) ->
    candidates = @getCandidates()
    # initial decoration to unmatch
    @decorateMatches @matches, 'rapid-motion-unmatch'
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

    @matchForCursor ?= @getMatchForCursor()
    @matches = _.sortBy @matches, (m) -> m.getScore()
    @index = _.sortedIndex @matches, @matchForCursor, (m) -> m.getScore()

    @decorateMatches @matches, 'rapid-motion-match'
    # Decorate Top and Bottom match differently
    @matches[0].decorate 'rapid-motion-match top'
    if @matches.length > 1
      @matches[@matches.length-1].decorate 'rapid-motion-match bottom'

    # @index can be 0 - N
    # Adjusting @index here to adapt to modification by @updateIndex().
    @index -= 1 if direction is 'forward'
    @updateCurrent @matches[@updateIndex(direction)]

  updateCurrent: (match) ->
    @lastCurrent?.decorate 'current', 'remove'
    match.decorate 'current', 'append'
    match.flash()
    match.scroll()
    @showHover match if atom.config.get('rapid-motion.showHoverIndicator')
    @lastCurrent = match

  showHover: (match) ->
    @container = new Container()
    @container.initialize @editor
    @hover?.destroy()
    @hover = new Hover()
    @hover.initialize {@editor, match}
    @container.appendChild @hover
    @hover.setContent @getCount()

  updateIndex: (direction) ->
    if direction is 'forward'
      @index += 1
      @index = 0 if @index is @matches.length
    else if direction is 'backward'
      @index -= 1
      @index = (@matches.length - 1) if @index is -1
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
    if @candidateProvider?
      _.defer =>
        @candidateProvider?.destroy()
        @candidateProvider = null
    @matches = []
    @container?.destroy()
    @hover?.destroy()


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

  saveEditorState: ->
    @editorState = {scrollTop: @editor.getScrollTop()}

  restoreEditorState: ->
    @editor.setScrollTop @editorState.scrollTop if @editorState?
