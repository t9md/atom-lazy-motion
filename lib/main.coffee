{CompositeDisposable, Range} = require 'atom'
Hover = require './hover'
_ = require 'underscore-plus'
settings = require './settings'
{MatchList} = require './match'
UI = require './ui'

module.exports =
  subscriptions: null
  config: settings.config
  historyManager: null

  activate: ->
    @ui = new UI
    @ui.initialize(this)
    @historyManager = @getHistoryManager()
    @observeUI()

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'lazy-motion:forward': => @start 'next'
      'lazy-motion:backward': => @start 'prev'
      'lazy-motion:forward-again': => @start 'next', action: 'again'
      'lazy-motion:backward-again': => @start 'prev', action: 'again'
      'lazy-motion:forward-cursor-word': => @start 'next', action: 'cursorWord'
      'lazy-motion:backward-cursor-word': => @start 'prev', action: 'cursorWord'

  observeUI: ->
    @ui.onDidChange ({text}) =>
      @search text
      @updateCounter()

    @ui.onDidConfirm ({text, where}) =>
      @historyManager.save text
      @land(where)

    @ui.onDidCancel ({text}) =>
      if settings.get('saveHistoryOnCancel')
        @historyManager.save text
      @cancel()

    @ui.onDidCommand (command) => @handleCommand(command)

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @historyManager.destroy()
    {@historyManager, @ui, @subscriptions} = {}
    @reset()

  start: (@direction, {action}={}) ->
    unless @ui.isVisible()
      @editor = atom.workspace.getActiveTextEditor()
      @restoreEditorState = @saveEditorState @editor
      @matches = new MatchList(@editor, @getWordPattern())
      switch action
        when 'again' then @handleCommand('set-history-prev')
        when 'cursorWord' then @handleCommand('set-cursor-word')
      @ui.focus()
    else
      return if @matches.isEmpty()
      @matches.visit(@direction)
      @updateCounter()

  updateCounter: ->
    count = @matches.getInfo()
    {total, current} = count
    content = if total isnt 0 then "#{current} / #{total}" else "0"
    @ui.updateCounter(content)

    if settings.get('showHoverIndicator') and total isnt 0
      @hover ?= new Hover()
      @hover.show @editor, @matches.get(), "#{current}/#{total}"

  handleCommand: (command) ->
    switch command
      when 'set-history-next'
        @ui.setText entry if entry = @historyManager.get('next')
      when 'set-history-prev'
        @ui.setText entry if entry = @historyManager.get('prev')
      when 'set-cursor-word'
        # [NOTE] We shouldn't simply use cursor::wordRegExp().
        # Instead use lazy-motion.wordRegExp setting.
        @setText @main.editor.getWordUnderCursor({wordRegex: @getWordPattern()})

  search: (text) ->
    @matches.reset()
    if (@ui.isMode('normal') and not text)
      return
    @matches.filter(text, mode: @ui.getMode())
    if @matches.isEmpty()
      @debouncedFlashScreen()
      @ui.hover?.reset()
      return

    if @matches.isOnly() and settings.get('autoLand')
      @ui.confirm()
      return

    @matches.visit()

  cancel: ->
    @restoreEditorState()
    @reset()

  land: (where="start") ->
    point = @matches.get().range[where]
    if @editor.getLastSelection().isEmpty()
      @editor.setCursorBufferPosition(point)
    else
      @editor.selectToBufferPosition point
    @reset()

  reset: ->
    @historyManager.reset()
    @hover?.reset()
    @matches?.destroy()
    {@flashingTimeout, @restoreEditorState, @matches, @direction} = {}

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
        @ui.cancel()

  # Accessed from UI
  # -------------------------
  # getCount: ->
  #   @matches.getInfo()

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
