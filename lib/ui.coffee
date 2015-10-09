{Emitter, CompositeDisposable} = require 'atom'
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
    @emitter = new Emitter
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

  onDidChange:  (fn) -> @emitter.on 'did-change', fn
  onDidConfirm: (fn) -> @emitter.on 'did-confirm', fn
  onDidCancel:  (fn) -> @emitter.on 'did-cancel', fn
  onDidUnfocus: (fn) -> @emitter.on 'did-unfocus', fn
  onDidCommand: (fn) -> @emitter.on 'did-command', fn

  handleInput: ->
    @editor.onDidChange =>
      return if @finishing
      text = @editor.getText()
      if text.length >= settings.get('minimumInputLength')
        @emitter.emit 'did-change', {text}
      @showCounter()

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

  setText: (text) ->
    @editor.setText text

  setHistory: (direction) ->
    if entry = @main.historyManager.get(direction)
      @setText entry

  setCursorWord: ->
    wordRegex = @main.getWordPattern()
    # [NOTE] We shouldn't simply use cursor::wordRegExp().
    # Instead use lazy-motion.wordRegExp setting.
    @setText @main.editor.getWordUnderCursor({wordRegex})

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
          @setText @normalModeText
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
    @setText ''
    @normalModeText = null
    @panel.hide()
    @setMode('normal')
    atom.workspace.getActivePane().activate()
    @finishing = false

  confirm: (where) ->
    @finishing = true
    event = {text: @editor.getText(), where}
    @emitter.emit 'did-confirm', event
    @unFocus()

  cancel: ->
    # [NOTE] blur event happen on confirmed() in this case we shouldn't cancel
    return if @finishing
    @finishing = true
    event = {text: @editor.getText()}
    @emitter.emit 'did-cancel', event
    @unFocus()

  isVisible: ->
    @panel.isVisible()

  destroy: ->
    @emitter.dispose()
    @hover?.destroy()
    @panel.destroy()
    @editor.destroy()
    @subscriptions.dispose()
    {@emitter, @hover, @panel, @editor, @subscriptions} = {}
    @remove()

module.exports =
document.registerElement 'lazy-motion-ui',
  extends: 'div'
  prototype: UI.prototype
