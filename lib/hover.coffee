class Hover extends HTMLElement
  createdCallback: ->
    @classList.add 'lazy-motion-hover'
    this

  show: (editor, match, @textContent) ->
    @classList.remove 'top'
    @classList.remove 'bottom'
    @classList.add 'top'    if match.isTop()
    @classList.add 'bottom' if match.isBottom()

    @createOverlay editor, match.range

  createOverlay: (editor, range)->
    @marker = editor.markBufferRange range,
      invalidate: "never",
      persistent: false

    decoration = editor.decorateMarker @marker,
      type: 'overlay'
      item: this
      position: 'head'

  destroy: ->
    @marker?.destroy()
    @remove()

Hover = document.registerElement 'lazy-motion-hover',
  prototype: Hover.prototype
  extends:   'div'

module.exports = Hover
