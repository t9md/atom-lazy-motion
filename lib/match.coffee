_ = require 'underscore-plus'

class Match
  constructor: (@editor, {@range, @matchText}) ->
    {@start, @end} = @range

  isTop: ->
    @decoration.getProperties()['class'].match 'top'

  isBottom: ->
    @decoration.getProperties()['class'].match 'bottom'

  decorate: (klass, {action}={}) ->
    action ?= 'replace'
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
    @score ?= (
      {row, column} = @start
      row * 1000 + column
    )

  destroy: ->
    @range = @start = @end = @score = @editor = null
    @marker?.destroy()
    @marker = @decoration = null

class MatchList
  constructor: ->
    @index     = 0
    @entries   = []
    @lastMatch = null

  replace: (@entries) ->

  isEmpty:    -> @entries.length is 0
  isOnly:     -> @entries.length is 1
  getCurrent: -> @entries[@index]

  visit: (direction, {from, redrawAll}={}) ->
    if from
      @setIndex direction, from
    else
      @updateIndex direction
    @redraw {all: redrawAll}

  setIndex: (direction, matchCursor) ->
    @entries = _.sortBy @entries, (m) -> m.getScore()
    @index   = _.sortedIndex @entries, matchCursor, (m) -> m.getScore()
    # Adjusting @index here to adapt to modification by @updateIndex().
    @index -= 1 if direction is 'forward'
    @updateIndex direction

    # If entry is containd in cursor position, we want next entry.
    if @getCurrent().range.containsPoint(matchCursor.start) and not @isOnly()
      @updateIndex direction

  updateIndex: (direction) ->
    if direction is 'forward'
      @index = (@index + 1) % @entries.length
    else
      @index -= 1
      @index = (@entries.length - 1) if @index is -1

  redraw: ({all}={}) ->
    if all
      [first, others..., last] = @entries
      @decorate others, 'lazy-motion-match'
      first.decorate 'lazy-motion-match top'
      last?.decorate 'lazy-motion-match bottom'

    # update current
    @lastMatch?.decorate 'current', action: 'remove'
    current = @getCurrent()
    current.decorate 'current', action: 'append'
    current.scroll()
    current.flash()
    @lastMatch = current

  decorate: (matches, klass) ->
    for m in matches ? []
      m.decorate klass

  reset: ->
    @decorate @entries, 'lazy-motion-unmatch'
    @replace([])

  getInfo: ->
    total: @entries.length,
    current: if @isEmpty() then 0 else @index+1

  destroy: ->
    @index = @entries = @lastMatch = null

module.exports = {Match, MatchList}
