_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'
{CompositeDisposable} = require 'atom'
{selectVisibleBy, getIndex, flash, getView} = require './utils'

class MatchList
  candidateProvider: null
  tokensAll: null
  tokensDivided: null
  visibles: null
  matches: null
  index: -1

  constructor: (@editor, @pattern) ->
    @subscriptions = new CompositeDisposable
    @editorElement = getView(@editor)

    @subscriptions.add @editorElement.onDidChangeScrollTop => @refresh()
    @subscriptions.add @editorElement.onDidChangeScrollLeft => @refresh()

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
        # @editor.scanInBufferRange /(?:[A-Z][a-z]+|[a-z]+)/g, m.range, ({range, matchText}) =>
        @editor.scanInBufferRange /\w+/g, m.range, ({range, matchText}) =>
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
    if _.isEmpty(text)
      @matches = matches
      return
    for text in text.trim().split(/\s+/)
      found = fuzzaldrin.filter(@getTokens(), text, key: 'matchText')
      matches =
        if matches.length is 0
          found
        else
          # @narrow(text, matches)
          # @narrowWithinSameLine(text, matches)
          # @filterSameLine(found, matches)
          @filterFollwing(found, matches)

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
    for match in @matches ? []
      match.reset()

  show: ->
    visibleMatches = selectVisibleBy(@editor, @matches, (match) -> match.range)
    for match in visibleMatches
      match.show()

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
    current: if @isEmpty() then 0 else @index + 1

  destroy: ->
    marker.destroy() for marker in (@matches ? [])
    marker.destroy() for marker in (@tokensAll ? [])
    marker.destroy() for marker in (@tokensDivided ? [])
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
      @first and 'first',
      last and 'last',
      @current and 'current'
    ].filter (e) -> e

  isFollowing: (other) ->
    return false unless (@range.start.row is other.range.start.row)
    @range.start.isGreaterThan(other.range.start)

  isFirst: -> @first
  isLast: -> @last
  isCurrent: -> @current

  show: ->
    klass = 'lazy-motion-match'
    klass += (" " + s) if (s = @getClassList().join(' ')).length
    @marker = @editor.markBufferRange @range, {invalidate: 'never', persistent: false}
    @editor.decorateMarker @marker, {type: 'highlight', class: klass}

  visit: ->
    point = @range.start
    @editor.scrollToBufferPosition(point, center: true)
    if @editor.isFoldedAtBufferRow(point.row)
      @editor.unfoldBufferRow point.row
    @flash()

  flash: ->
    return unless @marker?
    range = @marker.getBufferRange()
    flash(@editor, range, {class: 'lazy-motion-flash', timeout: 150})

  getScore: ->
    unless @score?
      {row, column} = @range.start
      @score = row * 1000 + column
    @score

  reset: ->
    @marker?.destroy()

  destroy: ->
    @reset()
    {@range, @score, @editor, @marker} = {}

module.exports = {Match, MatchList}
