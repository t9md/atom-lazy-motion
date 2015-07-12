_ = require 'underscore-plus'

module.exports =
class Match
  constructor: (@editor, {@range, @matchText}) ->
    {@start, @end} = @range
    # @decorateMarker klass

  isEqual: (other) ->
    @start.isEqual other.start

  decorate: (klass, action='replace') ->
    options = {type: 'highlight', class: klass}
    # action = 'replace'
    unless @decoration?
      @decoration = @decorateMarker options
      return

    switch action
      when 'replace'
        @decoration.setProperties options
      when 'remove'
        console.log '### remove'
        # [NOTE]
        # properties have 'id' field and directry pass to setProperties
        # cause error.
        prop = @decoration.getProperties()
        klass = prop['class'].replace(klass, '')
        options['class'] = klass.trim()
        @decoration.setProperties options

        console.log 'remove:after'
        console.log @decoration.getProperties()
      when 'append'
        console.log '### append'
        prop = @decoration.getProperties()
        options['class'] = prop['class'] + " #{klass}"
        @decoration.setProperties options

        console.log 'append:after'
        console.log @decoration.getProperties()

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
