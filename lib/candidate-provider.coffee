Match = require './match'

module.exports =
class CandidateProvider
  candidates: null

  constructor: (@editor, @wordPattern) ->
    @candidates = @buildCandidates()

  getCandidates: ->
    @candidates

  buildCandidates: ->
    matches = []
    @editor.scan @wordPattern, ({range, matchText}) =>
      matches.push new Match(@editor, {range, matchText})
    matches

  destroy: ->
    for match in @candidates
      match.destroy()
    @candidates = null
    @editor = null
    @wordPattern = null
