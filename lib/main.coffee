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
      'lazy-motion:forward':  => @start 'forward'
      'lazy-motion:backward': => @start 'backward'

  getWordPattern: ->
    scope = @editor.getRootScopeDescriptor()
    pattern = atom.config.get('lazy-motion.wordRegExp', {scope})
    error = null
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


  deactivate: ->
    @ui?.destroy()
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
      ui.showCounter()

  decorateMatches: (matches, klass) ->
    for m in matches ? []
      m.decorate klass

  getCandidates: ->
    @candidateProvider ?= new CandidateProvider(@editor, @getWordPattern())
    @candidateProvider.getCandidates()

  search: (direction, text) ->
    candidates = @getCandidates()
    # initial decoration to unmatch
    @decorateMatches @matches, 'lazy-motion-unmatch'
    @matches = []
    return unless text

    @matches = filter candidates, text, key: 'matchText'
    unless @matches.length
      @restoreEditorState()
      @debounceFlashScreen()
      @hover?.destroy()
      @container?.destroy()
      return

    if @matches.length is 1 and atom.config.get('lazy-motion.autoLand')
      @index = 0
      @getUI().confirm()
      return

    @matchForCursor ?= @getMatchForCursor()
    @matches = _.sortBy @matches, (m) -> m.getScore()
    @index = _.sortedIndex @matches, @matchForCursor, (m) -> m.getScore()

    @decorateMatches @matches, 'lazy-motion-match'
    # Decorate Top and Bottom match differently
    @matches[0].decorate 'lazy-motion-match top'
    if @matches.length > 1
      @matches[@matches.length-1].decorate 'lazy-motion-match bottom'

    # @index can be 0 - N
    # Adjusting @index here to adapt to modification by @updateIndex().
    @index -= 1 if direction is 'forward'
    @updateCurrent @matches[@updateIndex(direction)]

  updateCurrent: (match) ->
    @lastCurrent?.decorate 'current', 'remove'
    match.decorate 'current', 'append'
    match.flash()
    match.scroll()
    @showHover match if atom.config.get('lazy-motion.showHoverIndicator')
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
    match.decorate 'lazy-motion-cursor'
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
    @hover?.destroy()
    @container?.destroy()


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
      class: 'lazy-motion-flash'

    @flashingTimeout = setTimeout =>
      @flashingDecoration.getMarker().destroy()
      @flashingDecoration = null
    , 150

  saveEditorState: ->
    @editorState = {scrollTop: @editor.getScrollTop()}

  restoreEditorState: ->
    @editor.setScrollTop @editorState.scrollTop if @editorState?
