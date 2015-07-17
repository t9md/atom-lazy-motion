{CompositeDisposable, Range} = require 'atom'

fuzzaldrin = require 'fuzzaldrin'
_ = require 'underscore-plus'
settings = require './settings'

Match = null
MatchList = null

module.exports =
  subscriptions: null
  config: settings.config
  historyManager: null

  activate: ->
    {Match, MatchList} = require './match'
    @historyManager   = @getHistoryManager()

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'lazy-motion:forward':              => @start 'forward'
      'lazy-motion:backward':             => @start 'backward'
      'lazy-motion:forward-again':        => @start 'forward',  action: 'again'
      'lazy-motion:backward-again':       => @start 'backward', action: 'again'
      'lazy-motion:forward-cursor-word':  => @start 'forward',  action: 'cursorWord'
      'lazy-motion:backward-cursor-word': => @start 'backward', action: 'cursorWord'

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @historyManager.destroy()
    @reset()

  start: (@direction, {action}={}) ->
    ui = @getUI()
    unless ui.isVisible()
      @editor = @getEditor()
      @restoreEditorState = @saveEditorState @editor
      @matches = new MatchList()
      switch action
        when 'again'      then ui.setHistory 'prev'
        when 'cursorWord' then ui.setCursorWord()
      ui.focus()
    else
      return if @matches.isEmpty()
      @matches.visit @direction
      ui.showCounter()

  search: (text) ->
    @matches.reset()
    return unless text

    @matches.replace fuzzaldrin.filter(@getCandidates(), text, key: 'matchText')
    if @matches.isEmpty()
      @debouncedFlashScreen()
      return

    if @matches.isOnly() and settings.get('autoLand')
      @getUI().confirm()
      return

    @matchCursor ?= @getMatchForCursor()
    @matches.visit @direction, from: @matchCursor, redrawAll: true

  getCandidates: ->
    @candidateProvider ?= @getCandidateProvider(@editor, @getWordPattern())
    @candidateProvider.get()

  getCandidateProvider: (editor, pattern) ->
    matches = null

    get: ->
      return matches if matches
      matches = []
      editor.scan pattern, ({range, matchText}) =>
        matches.push new Match(editor, {range, matchText})
      matches

    destroy: ->
      for match in matches
        match.destroy()
      matches = null

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
    @historyManager.reset()

    @flashingTimeout    = null
    @restoreEditorState = null

    @matchCursor?.destroy()
    @matchCursor = null

    @candidateProvider?.destroy()
    @candidateProvider = null

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
    pattern = settings.get('wordRegExp', {scope})

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

  getHistoryManager: ->
    entries = []
    index = -1

    get: (direction) ->
      if direction is 'prev'
        index = (index + 1) % entries.length
      else if direction is 'next'
        index -= 1
        index = (entries.length - 1) if index < 0
      entries[index]

    save: (entry) ->
      return if _.isEmpty(entry)
      entries.unshift entry
      entries = _.uniq entries # Eliminate duplicates
      if entries.length > settings.get('historySize')
        entries.splice settings.get('historySize')

    reset: ->
      index = -1

    destroy: ->
      entries = null
      index = null

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
