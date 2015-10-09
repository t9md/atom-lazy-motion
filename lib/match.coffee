_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'
{CompositeDisposable} = require 'atom'
{selectVisibleBy, getIndex} = require './utils'

class MatchList
  candidateProvider: null
  tokensAll: null
  tokensDivided: null
  visibles: null
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
        @editor.scanInBufferRange /[\w-_]+/g, m.range, ({range, matchText}) =>
          matches.push new Match(@editor, {range, matchText})
      @tokensDivided = matches

  isDivided: ->
    @tokensDivided?

  clearDivided: ->
    @tokensDivided = null

  narrow: (text, matches) ->
    narrowed = []
    pattern = _.escapeRegExp(text)
    for m in matches
      @editor.scanInBufferRange ///#{pattern}///gi, m.range, ({range, matchText}) =>
        narrowed.push new Match(@editor, {range, matchText})
    narrowed

  narrowWithinSameLine: (text, matches) ->
    ranges =
      for row in _.uniq(range.start.row for {range} in matches)
        @editor.bufferRangeForBufferRow(row)

    pattern = _.escapeRegExp(text)
    narrowed = []
    for range in ranges
      @editor.scanInBufferRange ///#{pattern}///gi, range, ({range, matchText}) =>
        narrowed.push new Match(@editor, {range, matchText})
    narrowed

  filterFollwing: (found, matches) ->
    (f for f in found when _.detect(matches, (m) -> f.isFollowing(m)))

  filterSameLine: (found, matches) ->
    rows = _.uniq((range.start.row for {range} in matches))
    (m for m in found when m.range.start.row in rows)

  filter: (text) ->
    matches = []
    for text in text.trim().split(/\s+/)
      found = fuzzaldrin.filter(@getTokens(), text, key: 'matchText')
      matches =
        if matches.length is 0
          found
        else
          # @narrow(text, matches)
          @narrowWithinSameLine(text, matches)
          # @filterFollwing(found, matches)
          # @filterSameLine(found, matches)

    @matches = _.sortBy(matches, (m) -> m.getScore())
    return unless matches.length

    index = 0
    point = @editor.getCursorBufferPosition()
    for m, i in @matches when m.range.start.isGreaterThan(point)
      index = i
      break
    @setIndex(index)

    [first, others..., last] = @matches
    first.first = true
    last?.last = true
    @show()

  visit: (direction) ->
    @get(direction).visit()

  reset: ->
    m.reset() for m in (@matches ? [])

  show: ->
    for m in selectVisibleBy(@editor, @matches, (m) -> m.range)
      m.show()

  refresh: ->
    @reset()
    @show()

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
    m.destroy() for m in @matches ? []
    m.destroy() for m in @tokensAll ? []
    m.destroy() for m in @tokensDivided ? []
    @subscriptions.dispose()
    {
      @index, @tokensAll, @tokensDivided, @matches,
      @subscriptions, @visibles,
    } = {}

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
