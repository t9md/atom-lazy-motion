_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'
{CompositeDisposable} = require 'atom'
{selectVisibleBy, getIndex} = require './utils'

class MatchList
  candidateProvider: null
  tokensAll: null
  tokensDivided: null
  matches: null
  index: -1

  constructor: (@editor, @pattern) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add @editor.onDidChangeScrollTop => @refresh()
    @subscriptions.add @editor.onDidChangeScrollLeft => @refresh()

  isEmpty: ->
    if @matches?
      @matches.length is 0
    else
      true

  isOnly: ->
    @matches.length is 1

  getTokens: ->
    unless @tokensAll?
      matches = []
      @editor.scan @pattern, ({range, matchText}) =>
        matches.push new Match(@editor, {range, matchText})
      @tokensAll = matches

    if @tokensDivided?
      @tokensDivided
    else
      @tokensAll

  divide: ->
    unless @tokensDivided?
      matches = []
      for m in @matches
        @editor.scanInBufferRange /(?:[A-Z][a-z]+|[a-z]+)/g, m.range, ({range, matchText}) =>
          matches.push new Match(@editor, {range, matchText})
      @tokensDivided = matches

  isDivided: ->
    @tokensDivided?

  clearDivided: ->
    @tokensDivided = null

  narrow: (text, matches) ->
    # @narrowInitialPoint = @get().range.start.translate([0, -1])
    narrowed = []
    pattern = _.escapeRegExp(text)
    for m in matches
      @editor.scanInBufferRange ///#{pattern}///gi, m.range, ({range, matchText}) =>
        narrowed.push new Match(@editor, {range, matchText})
    narrowed

  filter: (text) ->
    tokens = @getTokens()
    point = @editor.getCursorBufferPosition()
    @reset()
    matches = []
    for text in text.trim().split(/\s+/)
      matches =
        if matches.length is 0
          fuzzaldrin.filter(tokens, text, key: 'matchText')
        else
          # @narrow(text, matches)
          found = fuzzaldrin.filter(tokens, text, key: 'matchText')
          (f for f in found when _.detect(matches, (m) -> f.isFollowing(m)))

    @matches = _.sortBy matches, (m) -> m.getScore()
    return unless matches.length
    index = 0
    for m, i in @matches when m.range.start.isGreaterThan(point)
      index = i
      break
    @setIndex(index)

    [first, others..., last] = @matches
    first.first = true
    last?.last = true
    @show()

  visit: (direction) ->
    @refresh()
    @get(direction).visit()

  refresh: ->
    @reset()
    @show()

  reset: ->
    m.reset() for m in (@matches ? [])

  show: ->
    for m in selectVisibleBy(@editor, @matches, (m) -> m.range)
      m.show()

  setIndex: (index) ->
    @index = getIndex(index, @matches)

  get: (direction=null) ->
    @matches[@index].current = false
    switch direction
      when 'next' then @setIndex(@index + 1)
      when 'prev' then @setIndex(@index - 1)
    match = @matches[@index]
    match.current = true
    match

  getInfo: ->
    total: @matches?.length ? 0,
    current: if @isEmpty() then 0 else @index+1

  destroy: ->
    @reset()
    m.destroy() for m in @tokensAll ? []
    m.destroy() for m in @tokensDivided ? []
    @subscriptions.dispose()
    {@index, @tokensAll, @tokensDivided, @matches, @subscriptions} = {}

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

  isFollowing: (other) ->
    return false if @range.start.row isnt other.range.start.row
    @range.start.isGreaterThan(other.range.start)

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
