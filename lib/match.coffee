_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin-plus'
{CompositeDisposable} = require 'atom'
{selectVisibleBy, getIndex, flash, getView} = require './utils'

class MatchList
  tokens: null
  entries: null
  index: -1

  constructor: (@editor, @pattern) ->
    @entries = []
    @subscriptions = new CompositeDisposable
    editorElement = getView(@editor)
    @subscribe editorElement.onDidChangeScrollTop => @refresh()
    @subscribe editorElement.onDidChangeScrollLeft => @refresh()

  subscribe: (args...) ->
    @subscriptions.add args...

  isEmpty: ->
    @entries.length is 0

  getTokens: ->
    unless @tokens?
      @tokens = []
      @editor.scan @pattern, ({range, matchText}) =>
        @tokens.push new Match(@editor, {range, matchText})
    @tokens

  filter: (text) ->
    @entries = @getTokens()
    matches = []
    for text, index in text.trim().split(/\s+/)
      found = fuzzaldrin.filter(@entries, text, key: 'matchText')
      if index is 0
        matches = found
      else
        matches = found.filter (found) ->
          _.detect(matches, (match) -> found.isFollowing(match))

    @entries = _.sortBy(matches, (match) -> match.getScore())
    return unless @entries.length

    index = 0
    point = @editor.getCursorBufferPosition()
    for match, i in @entries when match.range.start.isGreaterThan(point)
      index = i
      break
    @setIndex(index)

    [first, others..., last] = @entries
    first.first = true
    last?.last = true
    @refresh()

  visit: (direction) ->
    return unless match = @get(direction)

    {range} = match
    point = range.start
    @editor.scrollToBufferPosition(point, center: true)
    @editor.unfoldBufferRow point.row if @editor.isFoldedAtBufferRow(point.row)

    flash @editor, range,
      class: 'lazy-motion-flash'
      timeout: 150

    @refresh()

  refresh: ->
    @reset()
    for match in @getVisible()
      match.show()

  reset: ->
    for match in @entries
      match.reset()

  getVisible: ->
    selectVisibleBy @editor, @entries, (match) -> match.range

  setIndex: (index) ->
    @index = getIndex(index, @entries)

  get: (direction=null) ->
    @entries[@index].current = false
    switch direction
      when 'next' then @setIndex(@index + 1)
      when 'prev' then @setIndex(@index - 1)
    match = @entries[@index]
    match.current = true
    match

  getInfo: ->
    total: @entries?.length ? 0,
    current: if @isEmpty() then 0 else @index + 1

  destroy: ->
    marker.destroy() for marker in (@entries ? [])
    marker.destroy() for marker in (@tokens ? [])
    @subscriptions.dispose()
    {@index, @tokens,@entries, @subscriptions} = {}

class Match
  constructor: (@editor, {@range, @matchText}) ->

  getClassList: ->
    # first and last is exclusive, prioritize 'first'.
    classes = []
    classes.push('first') if @first
    classes.push('last') if (not @first and @last)
    classes.push('current') if @current
    classes

  isFollowing: ({range: {start: otherStart}}) ->
    {start} = @range
    if start.row is otherStart.row
      start.isGreaterThan(otherStart)
    else
      false

  show: ->
    classes = ['lazy-motion-match'].concat(@getClassList()...)

    @marker = @editor.markBufferRange @range,
      invalidate: 'never'
      persistent: false

    @editor.decorateMarker @marker,
      type: 'highlight'
      class: classes.join(" ")

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

module.exports = {MatchList}
