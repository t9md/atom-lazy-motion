_ = require 'underscore-plus'

module.exports =
class Match
  constructor: (@editor, {@range, @matchText, class: klass}) ->
    {@start, @end} = @range
    @decorateMarker klass

  decorate: (klass) ->
    options = {type: 'highlight', class: klass}
    if @decoration
      @decoration.setProperties options
    else
      @decoration = @decorateMarker options

  decorateMarker: (options) ->
    @marker = @editor.markBufferRange @range,
      invalidate: 'never'
      persistent: false
    @editor.decorateMarker @marker, options

  scroll: ->
    screenRange = @marker.getScreenRange()
    @editor.scrollToScreenRange screenRange
    bufferRow = @marker.getStartBufferPosition().row
    # [TODO] restore fold after land() or cancel()
    if @editor.isFoldedAtBufferRow(bufferRow)
      @editor.unfoldBufferRow(bufferRow)

  flash: ->
    decoration = @editor.decorateMarker @marker.copy(),
      type: 'highlight'
      class: 'isearch-flash'

    setTimeout  ->
      decoration.getMarker().destroy()
    , 150

  getScore: ->
    {row, column} = @start
    row * 1000 + column

  # To determine sorted order by _.sortedIndex which use binary search from sorted list.
  # getScore: (point) ->
  #   {row, column} = @start
  #   score = row * 1000 + column
  #   score = score * 10000 if @start.isLessThan(point)
  #   score

  land: (direction) ->
    point = @start
    if (@editor.getLastSelection().isEmpty())
      @editor.setCursorBufferPosition point
    else
      # [FIXME] Is it reasonable, need carefully think about?
      point = @end if direction is 'forward'
      @editor.selectToBufferPosition point

  destroy: ->
    @marker?.destroy()
