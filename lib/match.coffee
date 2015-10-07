_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'
{CompositeDisposable, Range} = require 'atom'

class MatchList
  candidateProvider: null

  constructor: (@editor, @pattern) ->
    @index    = -1
    @tokens   = []
    @matches = null
    @lastMatch = null
    @subscriptions = new CompositeDisposable
    @subscriptions.add @editor.onDidChangeScrollTop => @refresh()
    @subscriptions.add @editor.onDidChangeScrollLeft => @refresh()

  isEmpty: ->
    return true unless @matches
    @matches.length is 0

  isOnly: ->
    @matches.length is 1

  getTokens: ->
    matches = []
    @editor.scan @pattern, ({range, matchText}) =>
      matches.push new Match(@editor, {range, matchText})
    matches

  filter: (text) ->
    @reset()
    @tokens = @getTokens() if @isEmpty()
    matches = fuzzaldrin.filter(@tokens, text, key: 'matchText')
    @matches = _.sortBy matches, (m) -> m.getScore()
    return unless matches.length
    point = @editor.getCursorBufferPosition()
    index = 0
    for m, i in @matches when m.range.start.isGreaterThan(point)
      index = i
      break
    @setIndex(index)

    [first, others..., last] = @matches
    first.first = true
    last?.last = true
    @show()

  refresh: ->
    @reset()
    @show()

  reset: ->
    m.reset() for m in (@matches ? [])

  show: ->
    m.show() for m in @filterVisible(@matches)

  setIndex: (index) ->
    @index = @getIndex(index, @matches)

  # return adjusted index fit whitin length
  # return -1 if list is empty.
  getIndex: (index, list) ->
    return -1 unless list.length
    index = index % list.length
    if (index >= 0) then index else (list.length + index)

  get: (direction=null) ->
    @matches[@index].current = false
    switch direction
      when 'next' then @setIndex(@index + 1)
      when 'prev' then @setIndex(@index - 1)
    match = @matches[@index]
    match.current = true
    match

  getVisibleBufferRange: ->
    [startRow, endRow] = @editor.getVisibleRowRange().map (row) =>
      @editor.bufferRowForScreenRow row
    new Range([startRow, 0], [endRow, Infinity])

  filterVisible: (matches) ->
    range = @getVisibleBufferRange()
    (m for m in matches when range.containsRange(m.range))

  getInfo: ->
    total: @matches?.length ? 0,
    current: if @isEmpty() then 0 else @index+1

  destroy: ->
    @reset()
    @subscriptions.dispose()
    {@index, @tokens, @matches, @subscriptions} = {}

class Match
  constructor: (@editor, {@range, @matchText}) ->

  getClassList: ->
    # first and last is exclusive, prioritize 'first'.
    last = (not @first) and @last
    [
      @first   and 'first',
      last     and 'last',
      @current and 'current'
    ].filter (e) -> e

  isFirst: -> @first
  isLast: -> @last
  isCurrent: -> @current

  show: ->
    klass = 'lazy-motion-match'
    if s = @getClassList().join(' ')
      klass += " " + s
    @marker = @editor.markBufferRange @range,
      invalidate: 'never'
      persistent: false
    @editor.decorateMarker @marker,
      type: 'highlight'
      class: klass

  visit: ->
    point = @range.start
    @editor.scrollToBufferPosition(point, center: true)
    if @editor.isFoldedAtBufferRow(point.row)
      @editor.unfoldBufferRow point.row
    @flash()

  flash: ->
    marker = @marker.copy()
    decoration = @editor.decorateMarker marker,
      type: 'highlight'
      class: 'lazy-motion-flash'

    setTimeout  ->
      marker.destroy()
    , 150

  getScore: ->
    @score ?= (
      {row, column} = @range.start
      row * 1000 + column
    )

  reset: ->
    @marker?.destroy()

  destroy: ->
    @reset()
    {@range, @score, @editor, @marker} = {}

module.exports = {Match, MatchList}
