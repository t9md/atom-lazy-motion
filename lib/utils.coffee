{Range} = require 'atom'
_ = require 'underscore-plus'

# Return function to restore editor's scrollTop and fold state.
saveEditorState = (editor) ->
  scrollTop = editor.getScrollTop()
  foldStartRows = editor.displayBuffer.findFoldMarkers({}).map (m) ->
    editor.displayBuffer.foldForMarker(m).getStartRow()
  ->
    for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
      editor.foldBufferRow row
    editor.setScrollTop scrollTop

# return adjusted index fit whitin length
# return -1 if list is empty.
getIndex = (index, list) ->
  return -1 unless list.length
  index = index % list.length
  if (index >= 0) then index else (list.length + index)

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = editor.getVisibleRowRange().map (row) ->
    editor.bufferRowForScreenRow row
  new Range([startRow, 0], [endRow, Infinity])

# NOTE: depending on getVisibleRowRange
selectVisibleBy = (editor, entries, fn) ->
  range = getVisibleBufferRange.bind(this)(editor)
  (e for e in entries when range.containsRange(fn(e)))

getScreenFlasher = (options) ->
  flasher =
    clear: ->
      @marker?.destroy()
      if @timeoutTask?
        clearTimeout @timeoutTask
        @timeoutTask = null

    flash: (editor) ->
      @clear()
      [startRow, endRow] = editor.getVisibleRowRange().map (row) ->
        editor.bufferRowForScreenRow row

      range = new Range([startRow, 0], [endRow, Infinity])
      @marker = editor.markBufferRange range,
        invalidate: 'never'
        persistent: false

      editor.decorateMarker @marker,
        type: 'highlight'
        class: options.class

      @timeoutTask = setTimeout =>
        @clear()
      , 150

  if options.debounce?
    flasher.flash = _.debounce(flasher.flash.bind(flasher), options.debounce)
  flasher

getHistoryManager = ({max}={}) ->
  entries = []
  index = -1
  max ?= 300

  get: (direction) ->
    if direction is 'prev'
      index = (index + 1) % entries.length
    else if direction is 'next'
      index -= 1
      index = (entries.length - 1) if index < 0
    entries[index]

  save: (entry) ->
    return if _.isEmpty(entry)
    entries.unshift entry
    entries = _.uniq entries # Eliminate duplicates
    if entries.length > max
      entries.splice max

  reset: ->
    index = -1

  destroy: ->
    {entries, index} = {}

module.exports = {
  saveEditorState
  getVisibleBufferRange
  getIndex
  selectVisibleBy
  getScreenFlasher
  getHistoryManager
}
