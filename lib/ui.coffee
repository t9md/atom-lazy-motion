{CompositeDisposable} = require 'atom'

class UI extends HTMLElement
  createdCallback: ->
    @hiddenPanels = []
    @classList.add 'rapid-motion-ui'
    @container = document.createElement 'div'
    @matchCountContainer = document.createElement 'div'
    @container.className = 'editor-container'
    @appendChild @matchCountContainer
    @appendChild @container

  initialize: (@main) ->
    @editorView = document.createElement 'atom-text-editor'
    @editorView.classList.add 'editor', 'rapid-motion'
    @editorView.getModel().setMini true
    @editorView.setAttribute 'mini', ''
    @container.appendChild @editorView
    @editor = @editorView.getModel()
    @panel = atom.workspace.addBottomPanel item: this, visible: false

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor.rapid-motion',
      'core:confirm':   => @confirm()
      'rapid-motion:cancel': => @cancel()
      'core:cancel':    => @cancel()

    @handleInput()
    this

  focus: ->
    @cleared = false
    @panel.show()
    @editorView.focus()

  handleInput: ->
    @subscriptions = subs = new CompositeDisposable
    subs.add @editor.onDidChange =>
      return if @isCleared()
      @main.search @getDirection(), @editor.getText()
      @refresh()

    subs.add @editor.onDidDestroy =>
      subs.dispose()

  setDirection: (@direction) ->
  getDirection: ->
    @direction

  isVisible: ->
    @panel.isVisible()

  refresh: ->
    {total, current} = @main.getCount()
    content = "Total: #{total}"
    content += ", Current: #{current}" if total isnt 0
    @matchCountContainer.textContent = content

  confirm: ->
    unless @editor.getText()
      return
    @main.land()
    @clear()

  cancel: ->
    @main.cancel()
    @clear()

  clear: ->
    return if @isCleared()
    @cleared = true
    @editor.setText ''
    @panel.hide()
    atom.workspace.getActivePane().activate()

  isCleared: ->
    @cleared

  destroy: ->
    @panel.destroy()
    @subscriptions.dispose()
    @remove()

module.exports =
document.registerElement 'rapid-motion-ui',
  extends: 'div'
  prototype: UI.prototype
