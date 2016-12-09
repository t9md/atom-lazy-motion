{Emitter, CompositeDisposable} = require 'atom'
settings = require './settings'
{ElementBuilder} = require './utils'

class UI extends HTMLElement
  ElementBuilder.includeInto(this)

  createdCallback: ->
    @emitter = new Emitter
    @className = 'lazy-motion-ui'

    @appendChild(
      @counterContainer = @div
        classList: ['counter']
    )
    @appendChild(
      @editorContainer = @div
        classList: ['editor-container']
    ).appendChild(
      @editorElement = @atomTextEditor
        classList: ['editor', 'lazy-motion']
        attribute: {mini: ''}
    )

    @editor = @editorElement.getModel()
    @editor.setMini(true)
    @panel = atom.workspace.addBottomPanel(item: this, visible: false)
    this

  onDidChange: (fn) -> @emitter.on 'did-change', fn
  onDidConfirm: (fn) -> @emitter.on 'did-confirm', fn
  onDidCancel: (fn) -> @emitter.on 'did-cancel', fn
  onDidUnfocus: (fn) -> @emitter.on 'did-unfocus', fn
  onCommand: (fn) -> @emitter.on 'command', fn

  emitCommand: (command) ->
    @emitter.emit('command', command)

  initialize: (@main) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'core:cancel':  => @cancel()
      'core:move-down': => @emitCommand('set-history-next')
      'core:move-up': => @emitCommand('set-history-prev')
      'lazy-motion:set-history-next': => @emitCommand('set-history-next')
      'lazy-motion:set-history-prev': => @emitCommand('set-history-prev')
      'lazy-motion:set-cursor-word': => @emitCommand('set-cursor-word')

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem =>
      @cancel() if @isVisible()

    @editor.onDidChange =>
      return if @finishing
      @emitter.emit 'did-change', {text: @getText()}
    this

  updateCounter: (text) ->
    @counterContainer.textContent = "Lazy Motion: #{text}"

  setText: (text) ->
    @editor.setText(text)

  getText: ->
    @editor.getText()

  focus: ->
    @panel.show()
    @editorElement.focus()
    @updateCounter('0')

  unFocus: ->
    @setText '' if settings.get('clearSearchTextOnEverySearch')
    @panel.hide()
    atom.workspace.getActivePane().activate()
    @finishing = false

  confirm: ->
    return if @main.matchList.isEmpty()
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

module.exports = document.registerElement 'lazy-motion-ui',
  extends: 'div'
  prototype: UI.prototype
