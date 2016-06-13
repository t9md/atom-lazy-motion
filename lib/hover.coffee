class Hover extends HTMLElement
  marker: null

  createdCallback: ->
    @classList.add 'lazy-motion-hover'
    this

  show: (editor, match, @textContent) ->
    @reset()
    @classList.add(match.getClassList()...)
    @createOverlay editor, match

  createOverlay: (editor, {range}) ->
    @marker = editor.markBufferRange(range, invalidate: "never")
    editor.decorateMarker @marker,
      type: 'overlay'
      item: this
      position: 'head'

  reset: ->
    @classList.remove('first', 'last', 'current')
    @marker?.destroy()
    @marker = null

  destroy: ->
    @reset()
    @remove()

Hover = document.registerElement 'lazy-motion-hover',
  prototype: Hover.prototype
  extends:   'div'

module.exports = Hover
