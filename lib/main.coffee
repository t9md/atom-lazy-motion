{CompositeDisposable, Range} = require 'atom'

_ = require 'underscore-plus'
settings = require './settings'
{Match, MatchList} = require './match'

module.exports =
  subscriptions: null
  config: settings.config
  historyManager: null

  activate: ->
    @historyManager   = @getHistoryManager()

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'lazy-motion:forward': => @start 'next'
      'lazy-motion:backward': => @start 'prev'
      'lazy-motion:forward-again': => @start 'next', action: 'again'
      'lazy-motion:backward-again': => @start 'prev', action: 'again'
      'lazy-motion:forward-cursor-word': => @start 'next', action: 'cursorWord'
      'lazy-motion:backward-cursor-word': => @start 'prev', action: 'cursorWord'

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @historyManager.destroy()
    {@historyManager, @ui, @subscriptions} = {}
    @reset()

  start: (@direction, {action}={}) ->
    ui = @getUI()
    unless ui.isVisible()
      @editor = atom.workspace.getActiveTextEditor()
      @restoreEditorState = @saveEditorState @editor
      @matches = new MatchList(@editor, @getWordPattern())
      switch action
        when 'again'      then ui.setHistory 'prev'
        when 'cursorWord' then ui.setCursorWord()
      ui.focus()
    else
      return if @matches.isEmpty()
      match = @matches.get(@direction)
      @matches.refresh()
      match.visit()
      ui.showCounter()

  search: (text) ->
    @matches.reset()
    return unless text
    @matches.filter(text)
    if @matches.isEmpty()
      @debouncedFlashScreen()
      @ui.hover?.reset()
      return

    if @matches.isOnly() and settings.get('autoLand')
      @getUI().confirm()
      return

    match = @matches.get()
    match.visit()

  cancel: ->
    @restoreEditorState()
    @reset()

  land: ->
    point = @matches.get().range.start
    console.log point.toString()
    if @editor.getLastSelection().isEmpty()
      @editor.setCursorBufferPosition point
    else
      @editor.selectToBufferPosition point
    @reset()

  reset: ->
    @historyManager.reset()
    @matchCursor?.destroy()
    @matches?.destroy()
    {
      @flashingTimeout, @restoreEditorState, @matchCursor,
      @matches, @direction,
    } = {}

  getUI: ->
    @ui ?= (new (require './ui')).initialize(this)
    @ui

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
  # Return function to restore editor state.
  saveEditorState: (editor) ->
    scrollTop = editor.getScrollTop()
    foldStartRows = editor.displayBuffer.findFoldMarkers().map (m) ->
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
