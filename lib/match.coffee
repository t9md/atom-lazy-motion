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
  constructor: ->
    @index       = 0
    @matches     = []
    @lastCurrent = null

  replace: (@matches) ->

  isEmpty:    -> @matches.length is 0
  isOnly:     -> @matches.length is 1
  getFirst:   -> _.first @matches
  getLast:    -> _.last @matches
  getCurrent: -> @matches[@index]

  visit: (direction, options={}) ->
    @setIndex direction, options.from if options.from
    @updateIndex direction
    @redraw {all: options.redrawAll}

  updateIndex: (direction) ->
    if direction is 'forward'
      @index += 1
      @index = 0 if @index is @matches.length
    else if direction is 'backward'
      @index -= 1
      @index = (@matches.length - 1) if @index is -1
    @index

  decorate: (klass) ->
    for m in @matches ? []
      m.decorate klass

  setIndex: (direction, matchCursor)->
    @matches = _.sortBy @matches, (m) -> m.getScore()
    @index  = _.sortedIndex @matches, matchCursor, (m) ->
      m.getScore()
    # Adjusting @index here to adapt to modification by @updateIndex().
    @index -= 1 if direction is 'forward'

  redraw: (options={}) ->
    if options.all
      @decorate 'lazy-motion-match'
      @getFirst().decorate 'lazy-motion-match top'
      if @matches.length > 1
        @getLast().decorate 'lazy-motion-match bottom'

    # update current
    @lastCurrent?.decorate 'current', 'remove'
    current = @getCurrent()
    current.decorate 'current', 'append'
    current.scroll()
    current.flash()
    @lastCurrent = current

  reset: ->
    @decorate 'lazy-motion-unmatch'
    @replace([])

  getInfo: ->
    if @matches and (0 <= @index < @matches.length)
      { total: @matches.length, current: @index+1 }
    else
      { total: 0, current: 0 }

  destroy: ->
    @index = null
    @matches = null
    @lastCurrent = null

module.exports = {Match, MatchList}
