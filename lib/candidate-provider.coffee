_ = require 'underscore-plus'
Match = require './match'

module.exports =
class CandidateProvider
  candidates: null

  constructor: (@editor, @wordPattern) ->
    @candidates = null
    @buildCandidates()

  getCandidates: ->
    @candidates

  resetCandidates: ->
    for match in @candidates ? []
      match.decorate 'rapid-motion-unmatch'

  buildCandidates: ->
    range = [[0, 0], [@editor.getLastBufferRow(), Infinity]]
    @addCandidatesForRange range

  addCandidatesForRange: (range) ->
    matches = []
    @editor.scanInBufferRange @wordPattern, range, ({range, matchText}) =>
      matches.push new Match(@editor, {range, matchText, class: 'rapid-motion-unmatch'})
    @candidates = matches

  removeCandidatesForRange: (range) ->
    @candidates = _.reject @candidates, (match) =>
      range.containsRange(match.range)
