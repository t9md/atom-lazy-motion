{Emitter, CompositeDisposable} = require 'atom'
settings = require './settings'

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
      'click': => @cancel()
      'blur': => @cancel()

      'lazy-motion:divide': => @emitter.emit('command', 'toggle-divide')

      'core:move-down': => @emitter.emit('command', 'set-history-next')
      'core:move-up': => @emitter.emit('command', 'set-history-prev')

      'lazy-motion:set-history-next': => @emitter.emit('command', 'set-history-next')
      'lazy-motion:set-history-prev': => @emitter.emit('command', 'set-history-prev')

      'lazy-motion:set-cursor-word': => @emitter.emit('command', 'set-cursor-word')

    @handleInput()
    this

  onDidChange: (fn) -> @emitter.on 'did-change', fn
  onDidConfirm: (fn) -> @emitter.on 'did-confirm', fn
  onDidCancel: (fn) -> @emitter.on 'did-cancel', fn
  onDidUnfocus: (fn) -> @emitter.on 'did-unfocus', fn
  onCommand: (fn) -> @emitter.on 'command', fn

  handleInput: ->
    @editor.onDidChange =>
      return if @finishing
      text = @getText()
      # if text.length >= settings.get('minimumInputLength')
      @emitter.emit 'did-change', {text}

  updateCounter: (text) ->
    @counterContainer.textContent = "Lazy Motion: #{text}"

  setText: (text) ->
    @editor.setText text

  getText: ->
    @editor.getText()

  isMode: (mode) ->
    @mode is mode

  getMode: ->
    @mode

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
        @setText @normalModeText

  focus: ->
    @panel.show()
    @editorElement.focus()
    @updateCounter('0')

  unFocus: ->
    @setText ''
    @normalModeText = null
    @panel.hide()
    @setMode('normal')
    atom.workspace.getActivePane().activate()
    @finishing = false

  confirm: ->
    @finishing = true
    @emitter.emit 'did-confirm', {text: @getText()}
    @unFocus()

  cancel: ->
    # [NOTE] blur event happen on confirmed() in this case we shouldn't cancel
    return if @finishing
    @finishing = true
    @emitter.emit 'did-cancel', {text: @getText()}
    @unFocus()

  isVisible: ->
    @panel.isVisible()

  destroy: ->
    @emitter.dispose()
    @panel.destroy()
    @editor.destroy()
    @subscriptions.dispose()
    {@emitter, @panel, @editor, @subscriptions} = {}
    @remove()

module.exports =
document.registerElement 'lazy-motion-ui',
  extends: 'div'
  prototype: UI.prototype
