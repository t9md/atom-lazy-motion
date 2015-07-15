{CompositeDisposable} = require 'atom'

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

    @handleInput()
    this

  handleInput: ->
    @subscriptions = subs = new CompositeDisposable

    subs.add @editor.onDidChange =>
      text = @editor.getText()
      if text.length >= atom.config.get('lazy-motion.minimumInputLength')
        @main.search text
      @showCounter()

    subs.add @editor.onDidDestroy =>
      subs.dispose()

  showCounter: ->
    {total, current} = @main.getCount()
    content = if total isnt 0 then "#{current} / #{total}" else "0"
    @counterContainer.textContent = "Lazy Motion: #{content}"

  focus: ->
    @editor.setText ''
    @finished = false
    @panel.show()
    @editorElement.focus()
    @showCounter()

  unFocus: ->
    @panel.hide()
    atom.workspace.getActivePane().activate()

  confirm: ->
    return if @main.matches.isEmpty()
    @finished = true
    @main.land()
    @unFocus()

  cancel: ->
    # [NOTE] blur event happen on confirmed() in this case we shouldn't cancel
    return if @finished
    @finished = true
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
