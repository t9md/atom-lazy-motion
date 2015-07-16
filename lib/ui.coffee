{CompositeDisposable} = require 'atom'
settings = require './settings'
{HoverContainer}  = require './hover-indicator'

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
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor.lazy-motion',
      'core:confirm': => @confirm()
      'core:cancel':  => @cancel()
      'click':        => @cancel()
      'blur':         => @cancel()

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

    subs.add @editor.onDidDestroy =>
      subs.dispose()

  showCounter: ->
    count = @main.getCount()
    {total, current} = count
    content = if total isnt 0 then "#{current} / #{total}" else "0"
    @counterContainer.textContent = "Lazy Motion: #{content}"

    if settings.get('showHoverIndicator')
      @hoverContainer ?= new HoverContainer().initialize(@main.editor)
      @hoverContainer.hide()
      if total isnt 0
        @hoverContainer.show @main.matches.getCurrent(), count

  setHistory: (direction) ->
    if entry = @main.historyManager.get(direction)
      @editor.setText entry

  setCursorWord: ->
    wordRegex = @main.getWordPattern()
    # [NOTE] We shouldn't simply use cursor::wordRegExp().
    # Instead use lazy-motion.wordRegExp setting.
    @editor.setText @main.editor.getWordUnderCursor({wordRegex})

  focus: ->
    @panel.show()
    @editorElement.focus()
    @showCounter()

  unFocus: ->
    @editor.setText ''
    @hoverContainer?.destroy()
    @hoverContainer = null
    @panel.hide()
    atom.workspace.getActivePane().activate()
    @finishing = false

  confirm: ->
    return if @main.matches.isEmpty()
    @finishing = true
    @main.historyManager.save @editor.getText()
    @main.land()
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
    @panel.destroy()
    @editor.destroy()
    @subscriptions.dispose()
    @remove()

module.exports =
document.registerElement 'lazy-motion-ui',
  extends: 'div'
  prototype: UI.prototype
