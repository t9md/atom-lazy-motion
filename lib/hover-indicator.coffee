{CompositeDisposable} = require 'atom'

class Hover extends HTMLElement
  createdCallback: ->
    @classList.add 'lazy-motion-hover'
    @style.paddingLeft  = '0.2em'
    @style.paddingRight = '0.2em'
    @style.marginLeft   = '5px'
    this

  setPixelPosition: (editor, point) ->
    editorView  = atom.views.getView(editor)
    px          = editorView.pixelPositionForBufferPosition point
    top         = px.top  - editor.getScrollTop()
    left        = px.left - editor.getScrollLeft()
    @style.top  = top  + 'px'
    @style.left = left + 'px'
    
    @style.marginTop = if top <= 10 then '0px' else '-20px'

  show: ({editor, match, counter}) ->
    @classList.remove 'top'
    @classList.remove 'bottom'
    @classList.add 'top'    if match.isTop()
    @classList.add 'bottom' if match.isBottom()

    @setPixelPosition(editor, match.end)
    @subscriptions = new CompositeDisposable

    updateHover = => @setPixelPosition(editor, match.end)
    @subscriptions.add editor.onDidChangeScrollTop(updateHover)
    @subscriptions.add editor.onDidChangeScrollLeft(updateHover)

    {current, total} = counter
    @textContent = "#{current}/#{total}"

  destroy: ->
    @subscriptions.dispose()
    @remove()

class Container extends HTMLElement
  initialize: (@editor) ->
    @classList.add 'lazy-motion', 'hover-container'
    editorView = atom.views.getView @editor
    @overlayer = editorView.shadowRoot.querySelector('content[select=".overlayer"]')
    @overlayer.appendChild this
    this

  show: (match, counter) ->
    @hover?.destroy()
    @hover = new HoverElemnt()
    @appendChild @hover
    @hover.show {@editor, match, counter}

  hide: ->
    @hover?.destroy()

  destroy: ->
    @hover?.destroy()
    @overlayer = null
    @remove()

HoverElemnt = document.registerElement 'lazy-motion-hover',
  prototype: Hover.prototype
  extends:   'div'

module.exports =
  HoverContainer: document.registerElement 'lazy-motion-hover-container',
    prototype: Container.prototype
    extends:   'div'
