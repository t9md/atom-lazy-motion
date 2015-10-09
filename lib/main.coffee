{CompositeDisposable, Range} = require 'atom'
Hover = require './hover'
_ = require 'underscore-plus'
settings = require './settings'
{MatchList} = require './match'
{
  getHistoryManager,
  saveEditorState,
  getScreenFlasher
} = require './utils'
UI = require './ui'

module.exports =
  subscriptions: null
  config: settings.config
  historyManager: null

  activate: ->
    @ui = new UI
    @ui.initialize(this)
    @historyManager = getHistoryManager(max: settings.get('historySize'))

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

    @ui.onDidConfirm ({text, where}) =>
      @historyManager.save text
      @land(where)

    @ui.onDidCancel ({text}) =>
      if settings.get('saveHistoryOnCancel')
        @historyManager.save text
      @cancel()

    @ui.onDidCommand (command) =>
      @handleCommand(command)

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @historyManager.destroy()
    {@flasher, @historyManager, @ui, @subscriptions} = {}
    @reset()

  start: (@direction, {action}={}) ->
    unless @ui.isVisible()
      @editor = atom.workspace.getActiveTextEditor()
      @restoreEditorState = saveEditorState @editor
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
      when 'toggle-divide'
        if @matches.isDivided()
          @matches.clearDivided()
        else
          @matches.divide()
          @search @ui.getText()
          if @matches.isEmpty()
            @ui.setText('')

  search: (text) ->
    @matches.reset()
    if not @matches.isDivided() and not text
      return
    @matches.filter(text)
    if @matches.isEmpty()
      unless @matches.isDivided()
        @flashScreen()
        @hover?.reset()
      return

    if @matches.isOnly() and settings.get('autoLand')
      @ui.confirm()
      return
    @matches.visit()
    @updateCounter()

  cancel: ->
    @restoreEditorState()
    @reset()

  land: (where="start") ->
    point = @matches.get().range[where]
    if @editor.getLastSelection().isEmpty()
      @editor.setCursorBufferPosition(point)
    else
      @editor.selectToBufferPosition(point)
    @reset()

  reset: ->
    @historyManager.reset()
    @hover?.reset()
    @matches?.destroy()
    {@restoreEditorState, @matches, @direction} = {}

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

  # Utility
  # -------------------------
  flashScreen: ->
    unless @flasher?
      @flasher = getScreenFlasher
        class: 'lazy-motion-flash'
        debounce: 150,
    @flasher.flash @editor
