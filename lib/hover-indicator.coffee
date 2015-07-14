class Hover extends HTMLElement
  createdCallback: ->
    @classList.add 'lazy-motion-hover'
    @style.marginLeft   = '5px'
    @style.marginTop    = '-20px'
    @style.paddingLeft  = '0.2em'
    @style.paddingRight = '0.2em'
    this

  show: ({editor, match, counter}) ->
    @classList.remove 'top'
    @classList.remove 'bottom'
    @classList.add 'top'    if match.isTop()
    @classList.add 'bottom' if match.isBottom()

    editorView       = atom.views.getView(editor)
    px               = editorView.pixelPositionForBufferPosition match.end
    top              = px.top  - editor.getScrollTop()
    left             = px.left - editor.getScrollLeft()
    @style.top       = top  + 'px'
    @style.left      = left + 'px'
    @style.marginTop = '0px' if top <= 0

    {current, total} = counter
    @textContent = "#{current}/#{total}"

  destroy: ->
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
