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
    @editor.scrollToScreenRange screenRange, center: true
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

  land: ->
    @editor.setCursorBufferPosition @start

  destroy: ->
    @marker?.destroy()
    # hakone
