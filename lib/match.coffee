_ = require 'underscore-plus'
module.exports =
class Match
  constructor: (@editor, {@range, @matchText}) ->
    {@start, @end} = @range

  isTop: ->
    @decoration.getProperties()['class'].match 'top'

  isBottom: ->
    @decoration.getProperties()['class'].match 'bottom'

  decorate: (klass, action='replace') ->
    unless @decoration?
      @decoration = @decorateMarker {type: 'highlight', class: klass}
      return

    switch action
      when 'remove'
        klass = @decoration.getProperties()['class'].replace(klass, '').trim()
      when 'append'
        klass = @decoration.getProperties()['class'] + ' ' + klass

    @decoration.setProperties {type: 'highlight', class: klass}

  decorateMarker: (options) ->
    @marker = @editor.markBufferRange @range,
      invalidate: 'never'
      persistent: false

    @editor.decorateMarker @marker, options

  scroll: ->
    screenRange = @marker.getScreenRange()
    @editor.scrollToScreenRange screenRange, center: true
    bufferRow = @marker.getStartBufferPosition().row
    if @editor.isFoldedAtBufferRow(bufferRow)
      @unfold bufferRow

  unfold: (row) ->
    @foldsSaved = @editor.displayBuffer.foldsContainingBufferRow row
    @editor.unfoldBufferRow row

  restoreFold: ->
    return unless @foldsSaved
    folds = _.sortBy @foldsSaved, (fold) -> fold.getStartRow()
    for fold in folds.reverse()
      @editor.foldBufferRow fold.getStartRow()
    @foldsSaved = null

  flash: ->
    decoration = @editor.decorateMarker @marker.copy(),
      type: 'highlight'
      class: 'lazy-motion-flash'

    setTimeout  ->
      decoration.getMarker().destroy()
    , 150

  getScore: ->
    {row, column} = @start
    row * 1000 + column

  destroy: ->
    @marker?.destroy()
    @foldsSaved = null
