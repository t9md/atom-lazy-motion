_ = require 'underscore-plus'

module.exports =
class Match
  constructor: (@editor, {@range, @matchText}) ->
    {@start, @end} = @range

  isEqual: (other) ->
    @start.isEqual other.start

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
    @editor.scrollToScreenRange screenRange
    bufferRow = @marker.getStartBufferPosition().row
    # [TODO] restore fold after land() or cancel()
    if @editor.isFoldedAtBufferRow(bufferRow)
      @editor.unfoldBufferRow(bufferRow)

  flash: ->
    decoration = @editor.decorateMarker @marker.copy(),
      type: 'highlight'
      class: 'rapid-motion-flash'

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

  land: ->
    @editor.setCursorBufferPosition @start

  destroy: ->
    @marker?.destroy()
