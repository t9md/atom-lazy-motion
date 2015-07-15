{CompositeDisposable, Range, TextEditor} = require 'atom'

fuzzaldrin = require 'fuzzaldrin'
_ = require 'underscore-plus'

Match = null
MatchList = null
CandidateProvider = null
HoverContainer = null

Config =
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

module.exports =
  subscriptions: null
  config: Config
  container: null

  activate: ->
    {Match, MatchList} = require './match'
    {HoverContainer}   = require './hover-indicator'
    CandidateProvider  = require './candidate-provider'

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'lazy-motion:forward':  => @start 'forward'
      'lazy-motion:backward': => @start 'backward'

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @reset()

  start: (@direction) ->
    ui = @getUI()
    unless ui.isVisible()
      @editor = @getEditor()
      @restoreEditorState = @saveEditorState @editor
      @matches = new MatchList()
      ui.focus()
    else
      return if @matches.isEmpty()
      @matches.visit @direction
      if atom.config.get('lazy-motion.showHoverIndicator')
        @showHover @matches.getCurrent()
      ui.showCounter()

  getCandidates: ->
    @candidateProvider ?= new CandidateProvider(@editor, @getWordPattern())
    @candidateProvider.getCandidates()

  search: (text) ->
    @matches.reset()
    unless text
      @container?.hide()
      return

    @matches.replace fuzzaldrin.filter(@getCandidates(), text, key: 'matchText')
    if @matches.isEmpty()
      @debouncedFlashScreen()
      @container?.hide()
      return

    if @matches.isOnly() and atom.config.get('lazy-motion.autoLand')
      @getUI().confirm()
      return

    @matchCursor ?= @getMatchForCursor()
    @matches.visit @direction, from: @matchCursor, redrawAll: true

    if atom.config.get('lazy-motion.showHoverIndicator')
      @showHover @matches.getCurrent()

  showHover: (match) ->
    @container ?= new HoverContainer().initialize(@editor)
    @container.show match, @getCount()

  getMatchForCursor: ->
    start = @editor.getCursorBufferPosition()
    end = start.translate([0, 1])
    match = new Match(@editor, range: new Range(start, end))
    match.decorate 'lazy-motion-cursor'
    match

  cancel: ->
    @restoreEditorState()
    @reset()

  land: ->
    point = @matches.getCurrent().start
    if @editor.getLastSelection().isEmpty()
      @editor.setCursorBufferPosition point
    else
      @editor.selectToBufferPosition point
    @reset()

  reset: ->
    @flashingTimeout    = null
    @restoreEditorState = null

    @matchCursor?.destroy()
    @matchCursor = null

    @candidateProvider?.destroy()
    @candidateProvider = null

    @container?.destroy()
    @container = null

    @matches?.destroy()
    @matches = null

    @direction = null

  getUI: ->
    @ui ?= (
      ui = new (require './ui')
      ui.initialize this
      ui)

  getWordPattern: ->
    scope = @editor.getRootScopeDescriptor()
    pattern = atom.config.get('lazy-motion.wordRegExp', {scope})

    try
      new RegExp(pattern, 'g')
    catch error
      content = """
        lazy-motion:
        * Invalid regular expression `#{pattern}` on scope `#{scope}`.
        """
      atom.notifications.addWarning content, dismissable: true
    finally
      if error
        @getUI().cancel()

  # Accessed from UI
  # -------------------------
  getCount: ->
    @matches.getInfo()

  # Utility
  # -------------------------
  getEditor: ->
    atom.workspace.getActiveTextEditor()

  # Return function to restore editor state.
  saveEditorState: (editor) ->
    scrollTop = editor.getScrollTop()
    foldStartRows = editor.displayBuffer.findFoldMarkers().map (m) =>
      editor.displayBuffer.foldForMarker(m).getStartRow()
    ->
      for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
        editor.foldBufferRow row
      editor.setScrollTop scrollTop

  debouncedFlashScreen: ->
    @_debouncedFlashScreen ?= _.debounce @flashScreen.bind(this), 150, true
    @_debouncedFlashScreen()

  flashScreen: ->
    [startRow, endRow] = @editor.getVisibleRowRange().map (row) =>
      @editor.bufferRowForScreenRow row

    range = new Range([startRow, 0], [endRow, Infinity])
    marker = @editor.markBufferRange range,
      invalidate: 'never'
      persistent: false

    @flashingDecoration?.getMarker().destroy()
    clearTimeout @flashingTimeout

    @flashingDecoration = @editor.decorateMarker marker,
      type: 'highlight'
      class: 'lazy-motion-flash'

    @flashingTimeout = setTimeout =>
      @flashingDecoration.getMarker().destroy()
      @flashingDecoration = null
    , 150
