{CompositeDisposable, Range} = require 'atom'
_ = require 'underscore-plus'

Hover = require './hover'
settings = require './settings'
{MatchList} = require './match'
{getHistoryManager, saveEditorState, flashScreen} = require './utils'
UI = require './ui'

module.exports =
  subscriptions: null
  searchHistory: null

  activate: ->
    @ui = new UI().initialize(this)
    @searchHistory = getHistoryManager(max: settings.get('historySize'))
    settings.notifyAndRemoveDeprecate('autoLand', 'minimumInputLength')
    @observeUI()

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'lazy-motion:forward': => @start('next')
      'lazy-motion:backward': => @start('prev')
      'lazy-motion:forward-again': => @start('next', action: 'again')
      'lazy-motion:backward-again': => @start('prev', action: 'again')
      'lazy-motion:forward-cursor-word': => @start('next', action: 'cursorWord')
      'lazy-motion:backward-cursor-word': => @start('prev', action: 'cursorWord')

  observeUI: ->
    @ui.onDidChange ({text}) =>
      @search(text)
      @updateCounter()

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
      @matchList = new MatchList(@editor, @getWordPattern())
      switch action
        when 'again' then @handleCommand('set-history-prev')
        when 'cursorWord' then @handleCommand('set-cursor-word')
        else
          unless settings.get('clearSearchTextOnEverySearch')
            text = @ui.getText('')
            @ui.setText(text) unless _.isEmpty(text)
      @ui.focus()
    else
      return if @matchList.isEmpty()
      @matchList.visit(@direction)
      @updateCounter()

  updateCounter: ->
    {total, current} = @matchList.getInfo()
    content = if total isnt 0 then "#{current} / #{total}" else "0"
    @ui.updateCounter(content)

    if settings.get('showHoverIndicator') and total isnt 0
      @hover ?= new Hover()
      @hover.show @editor, @matchList.get(), "#{current}/#{total}"

  handleCommand: (command) ->
    switch command
      when 'set-history-next' then @ui.setText(@searchHistory.get('next'))
      when 'set-history-prev' then @ui.setText(@searchHistory.get('prev'))
      when 'set-cursor-word'
        # [NOTE] # Instead of cursor::wordRegExp(), we use lazy-motion.wordRegExp setting.
        cursorWord = @editor.getWordUnderCursor({wordRegex: @getWordPattern()})
        @ui.setText(cursorWord)

  search: (text) ->
    @matchList.reset()
    return unless text
    @matchList.filter(text)
    if @matchList.isEmpty()
      flashScreen @editor, {timeout: 100, class: 'lazy-motion-flash'}
      @hover?.reset()
      return
    @matchList.visit()

  cancel: ->
    @restoreEditorState()
    @reset()

  land: ->
    point = @matchList.get().range.start
    if @editor.getLastSelection().isEmpty()
      @editor.setCursorBufferPosition(point)
    else
      @editor.selectToBufferPosition(point)
    @reset()

  reset: ->
    @searchHistory.reset()
    @hover?.reset()
    @matchList?.destroy()
    {@restoreEditorState, @matchList, @direction} = {}

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
