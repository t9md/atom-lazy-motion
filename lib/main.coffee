{CompositeDisposable, Range, TextEditor} = require 'atom'

{filter} = require 'fuzzaldrin'
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
    {HoverContainer} = require './hover-indicator'
    CandidateProvider = require './candidate-provider'

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'lazy-motion:forward':  => @start 'forward'
      'lazy-motion:backward': => @start 'backward'

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @reset()

  start: (direction) ->
    ui = @getUI()
    unless ui.isVisible()
      @editor = atom.workspace.getActiveTextEditor()
      @restoreEditorState = @saveEditorState @editor
      ui.setDirection direction
      ui.focus()
    else
      ui.setDirection direction
      return unless @matches.length
      @updateCurrent @matches[@updateIndex(direction)]
      ui.showCounter()

  getCandidates: ->
    @candidateProvider ?= new CandidateProvider(@editor, @getWordPattern())
    @candidateProvider.getCandidates()

  search: (direction, text) ->
    @decorateMatches @matches, 'lazy-motion-unmatch'
    @matches = [] # Need to reset for showCounter().
    unless text
      @container?.hide()
      return

    @matches = filter @getCandidates(), text, key: 'matchText'
    unless @matches.length
      @debounceFlashScreen()
      @container?.hide()
      return

    if @matches.length is 1 and atom.config.get('lazy-motion.autoLand')
      @index = 0
      @getUI().confirm()
      return

    @matchCursor ?= @getMatchForCursor()
    @matches = _.sortBy @matches, (m) -> m.getScore()
    @refreshMatches @matches

    # Adjusting @index here to adapt to modification by @updateIndex().
    @index  = _.sortedIndex @matches, @matchCursor, (m) -> m.getScore()
    @index -= 1 if direction is 'forward'
    @updateCurrent @matches[@updateIndex(direction)]

  refreshMatches: (matches) ->
    @decorateMatches matches, 'lazy-motion-match'
    matches[0].decorate 'lazy-motion-match top'
    if matches.length > 1
      matches[matches.length-1].decorate 'lazy-motion-match bottom'

  decorateMatches: (matches, klass) ->
    for m in matches ? []
      m.decorate klass

  updateCurrent: (match) ->
    @lastCurrent?.decorate 'current', 'remove'
    match.decorate 'current', 'append'
    match.scroll()
    match.flash()
    if atom.config.get('lazy-motion.showHoverIndicator')
      @showHover match
    @lastCurrent = match

  showHover: (match) ->
    @container ?= new HoverContainer().initialize(@editor)
    @container.show match, @getCount()

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
    match.decorate 'lazy-motion-cursor'
    match

  cancel: ->
    @restoreEditorState()
    @reset()

  land: ->
    @editor.setCursorBufferPosition @matches[@index].start
    @reset()

  reset: ->
    @flashingTimeout    = null
    @restoreEditorState = null

    @matchCursor?.destroy()
    @matchCursor = null

    @candidateProvider?.destroy()
    @candidateProvider = null

    @lastCurrent = null
    @container?.destroy()
    @container = null

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
    @matches ?= []
    if @matches and (0 <= @index < @matches.length)
      { total: @matches.length, current: @index+1 }
    else
      { total: 0, current: 0 }

  # Utility
  # -------------------------
  debounceFlashScreen: ->
    @_debounceFlashScreen ?= _.debounce @flashScreen.bind(this), 150, true
    @_debounceFlashScreen()

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

  # Return function to restore editor state.
  saveEditorState: (editor) ->
    scrollTop = editor.getScrollTop()
    foldStartRows = editor.displayBuffer.findFoldMarkers().map (m) =>
      editor.displayBuffer.foldForMarker(m).getStartRow()
    ->
      for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
        editor.foldBufferRow row
      editor.setScrollTop scrollTop
