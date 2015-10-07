{CompositeDisposable} = require 'atom'
settings = require './settings'
Hover = require './hover'

class UI extends HTMLElement
  createdCallback: ->
    @classList.add 'lazy-motion-ui'

    @editorContainer = document.createElement 'div'
    @editorContainer.className = 'editor-container'

    @counterContainer = document.createElement 'div'
    @counterContainer.className = 'counter'

    @appendChild @counterContainer
    @appendChild @editorContainer

    @editorElement = document.createElement 'atom-text-editor'
    @editorElement.classList.add 'editor', 'lazy-motion'
    @editorElement.getModel().setMini true
    @editorElement.setAttribute 'mini', ''
    @editorContainer.appendChild @editorElement
    @editor = @editorElement.getModel()
    @panel = atom.workspace.addBottomPanel item: this, visible: false

  initialize: (@main) ->
    @setMode('normal')
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor.lazy-motion',
      'core:confirm': => @confirm()
      'core:cancel':  => @cancel()
      'click':        => @cancel()
      'blur':         => @cancel()

      'lazy-motion:cancel': => @cancel()
      'lazy-motion:land-to-start': => @confirm()
      'lazy-motion:land-to-end': => @confirm('end')
      'lazy-motion:divide': => @toggleDivide()
      'lazy-motion:set-history-next': => @setHistory('next')
      'lazy-motion:set-history-prev': => @setHistory('prev')
      'lazy-motion:set-cursor-word':  => @setCursorWord()

    @handleInput()
    this

  handleInput: ->
    @subscriptions = subs = new CompositeDisposable

    subs.add @editor.onDidChange =>
      return if @finishing
      text = @editor.getText()
      if text.length >= settings.get('minimumInputLength')
        @main.search text
      @showCounter()

    subs.add @editor.onDidDestroy ->
      subs.dispose()

  showCounter: ->
    count = @main.getCount()
    {total, current} = count
    content = if total isnt 0 then "#{current} / #{total}" else "0"
    @counterContainer.textContent = "Lazy Motion: #{content}"

    if settings.get('showHoverIndicator')
      @hover ?= new Hover()
      if total isnt 0
        currentMatch = @main.matches.get()
        content = "#{current}/#{total}"
        @hover.show @main.editor, currentMatch, content

  setHistory: (direction) ->
    if entry = @main.historyManager.get(direction)
      @editor.setText entry

  setCursorWord: ->
    wordRegex = @main.getWordPattern()
    # [NOTE] We shouldn't simply use cursor::wordRegExp().
    # Instead use lazy-motion.wordRegExp setting.
    @editor.setText @main.editor.getWordUnderCursor({wordRegex})

  isMode: (mode) ->
    @mode is mode

  getMode: -> @mode

  toggleDivide: ->
    mode = if @isMode('divide') then 'normal' else 'divide'
    @setMode(mode)

  setMode: (mode) ->
    oldMode = @getMode()
    if mode is 'divide' and @main.matches.isEmpty()
      return
    @mode = mode
    @classList.remove oldMode
    @classList.add mode

    switch mode
      when 'normal'
        if oldMode is 'divide' and @normalModeText
          @editor.setText @normalModeText
          @normalModeText = null
      when 'divide'
        @normalModeText = @editor.getText()
        @editor.setText ''

  focus: ->
    @panel.show()
    @editorElement.focus()
    @showCounter()

  unFocus: ->
    @hover?.reset()
    @editor.setText ''
    @normalModeText = null
    @panel.hide()
    @setMode('normal')
    atom.workspace.getActivePane().activate()
    @finishing = false

  confirm: (where) ->
    return if @main.matches.isEmpty()
    @finishing = true
    @main.historyManager.save @editor.getText()
    @main.land(where)
    @unFocus()

  cancel: ->
    # [NOTE] blur event happen on confirmed() in this case we shouldn't cancel
    return if @finishing
    @finishing = true
    if settings.get('saveHistoryOnCancel')
      @main.historyManager.save @editor.getText()
    @main.cancel()
    @unFocus()

  isVisible: ->
    @panel.isVisible()

  destroy: ->
    @hover?.destroy()
    @panel.destroy()
    @editor.destroy()
    @subscriptions.dispose()
    {@hover, @panel, @editor, @subscriptions} = {}
    @remove()

module.exports =
document.registerElement 'lazy-motion-ui',
  extends: 'div'
  prototype: UI.prototype
