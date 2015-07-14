_ = require 'underscore-plus'

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
      @editor.unfoldBufferRow bufferRow

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


class MatchList
  constructor: (@matches) ->
    @index = 0

  isEmpty: ->
    @matches.length is 0

  forward: ->
    @updateIndex 'forward'
    @updateCurrent()

  backward: ->
    @updateIndex 'backward'
    @updateCurrent()

  getIndex: ->
    @index

  updateIndex: (direction) ->
    if direction is 'forward'
      @index += 1
      @index = 0 if @index is @matches.length
    else if direction is 'backward'
      @index -= 1
      @index = (@matches.length - 1) if @index is -1
    @index

  getCurrent: ->
    @matches[@index]

  updateCurrent: ->
    current = @getCurrent()
    @lastCurrent?.decorate 'current', 'remove'
    current.decorate 'current', 'append'
    current.scroll()
    current.flash()
    @lastCurrent = current
    if atom.config.get('lazy-motion.showHoverIndicator')
      @showHover current

module.exports = {Match, MatchList}
