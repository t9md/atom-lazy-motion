{Range} = require 'atom'
_ = require 'underscore-plus'


saveEditorState = (editor) ->
  editorElement = editor.element
  scrollTop = editorElement.getScrollTop()

  foldStartRows = editor.displayLayer.foldsMarkerLayer.findMarkers({}).map (m) -> m.getStartPosition().row
  ->
    for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
      editor.foldBufferRow(row)
    editorElement.setScrollTop(scrollTop)

# Return adjusted index fit whitin length
# Return -1 if list is empty.
getIndex = (index, list) ->
  if list.length is 0
    -1
  else
    index = index % list.length
    if (index >= 0)
      index
    else
      list.length + index

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = getVisibleBufferRowRange(editor)
  new Range([startRow, 0], [endRow, Infinity])

getVisibleBufferRowRange = (editor) ->
  [startRow, endRow] = editor.element.getVisibleRowRange().map (row) ->
    editor.bufferRowForScreenRow row

# NOTE: depending on getVisibleRowRange
selectVisibleBy = (editor, entries, fn) ->
  range = getVisibleBufferRange(editor)
  (e for e in entries when range.containsRange(fn(e)))

getHistoryManager = ({max}={}) ->
  entries = []
  index = -1
  max ?= 20

  get: (direction) ->
    switch direction
      when 'prev' then index += 1 unless (index + 1) is entries.length
      when 'next' then index -= 1 unless (index is -1)
    entries[index] ? ''

  save: (entry) ->
    return if _.isEmpty(entry)
    entries.unshift entry
    entries = _.uniq(entries) # Eliminate duplicates
    if entries.length > max
      entries.splice(max)

  reset: ->
    index = -1

  destroy: ->
    {entries, index} = {}

flash = (editor, range, options) ->
  marker = editor.markBufferRange(range, invalidate: 'never')
  editor.decorateMarker(marker, type: 'highlight', class: options.class)

  setTimeout ->
    marker.destroy()
  , options.timeout

flashScreen = (editor, options) ->
  flash(editor, getVisibleBufferRange(editor), options)

ElementBuilder =
  includeInto: (target) ->
    for name, value of this when name isnt "includeInto"
      target::[name] = value.bind(this)

  div: (params) ->
    @createElement 'div', params

  span: (params) ->
    @createElement 'div', params

  atomTextEditor: (params) ->
    @createElement 'atom-text-editor', params

  createElement: (element, {classList, id, textContent, attribute}={}) ->
    element = document.createElement element

    element.id = id if id?
    element.classList.add classList... if classList?
    element.textContent = textContent if textContent?
    for name, value of attribute ? {}
      element.setAttribute(name, value)
    element

module.exports = {
  saveEditorState
  getVisibleBufferRange
  getVisibleBufferRowRange
  getIndex
  selectVisibleBy
  getHistoryManager
  flash
  flashScreen
  ElementBuilder
}
