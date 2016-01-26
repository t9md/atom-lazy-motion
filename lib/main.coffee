{CompositeDisposable, Range} = require 'atom'
_ = require 'underscore-plus'

Hover = require './hover'
settings = require './settings'
{MatchList} = require './match'
{
  getHistoryManager,
  saveEditorState,
  flashScreen
} = require './utils'
UI = require './ui'

module.exports =
  subscriptions: null
  searchHistory: null

  activate: ->
    @ui = new UI
    @ui.initialize(this)
    @searchHistory = getHistoryManager(max: settings.get('historySize'))
    settings.notifyAndRemoveDeprecate('autoLand')
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
      @search(text)

    @ui.onDidConfirm ({text}) =>
      @searchHistory.save text
      @land()

    @ui.onDidCancel ({text}) =>
      if settings.get('saveHistoryOnCancel')
        @searchHistory.save text
      @cancel()

    @ui.onCommand (command) =>
      @handleCommand(command)

  deactivate: ->
    @ui?.destroy()
    @subscriptions.dispose()
    @searchHistory.destroy()
    {@searchHistory, @ui, @subscriptions} = {}
    @reset()

  start: (@direction, {action}={}) ->
    unless @ui.isVisible()
      @editor = atom.workspace.getActiveTextEditor()
      @restoreEditorState = saveEditorState @editor
      @matches = new MatchList(@editor, @getWordPattern())
      switch action
        when 'again' then @handleCommand('set-search-prev')
        when 'cursorWord' then @handleCommand('set-cursor-word')
      @ui.focus()
    else
      return if @matches.isEmpty()
      @matches.visit(@direction)
      @updateCounter()

  updateCounter: ->
    {total, current} = @matches.getInfo()
    content = if total isnt 0 then "#{current} / #{total}" else "0"
    @ui.updateCounter(content)

    if settings.get('showHoverIndicator') and total isnt 0
      @hover ?= new Hover()
      @hover.show @editor, @matches.get(), "#{current}/#{total}"

  handleCommand: (command) ->
    switch command
      when 'set-search-next' then @ui.setText(@searchHistory.get('next'))
      when 'set-search-prev' then @ui.setText(@searchHistory.get('prev'))
      when 'set-cursor-word'
        # [NOTE] We shouldn't simply use cursor::wordRegExp().
        # Instead use lazy-motion.wordRegExp setting.
        @setText @editor.getWordUnderCursor({wordRegex: @getWordPattern()})
      when 'toggle-divide'
        if @matches.isDivided()
          @matches.clearDivided()
          @search @ui.getText()
        else
          @matches.divide()
          @search @ui.getText()
          @ui.setText('') if @matches.isEmpty()

  search: (text) ->
    @matches.reset()
    # if not @matches.isDivided() and (not text)
    #   @hover?.reset()
    #   return
    @matches.filter(text)
    if @matches.isEmpty()
      unless @matches.isDivided()
        flashScreen @editor, {timeout: 100, class: 'lazy-motion-flash'}
      @hover?.reset()
      return
    @matches.visit()
    @updateCounter()

  cancel: ->
    @restoreEditorState()
    @reset()

  land: ->
    point = @matches.get().range.start
    if @editor.getLastSelection().isEmpty()
      @editor.setCursorBufferPosition(point)
    else
      @editor.selectToBufferPosition(point)
    @reset()

  reset: ->
    @searchHistory.reset()
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
