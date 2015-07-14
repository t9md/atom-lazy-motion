{Match} = require './match'

module.exports =
class CandidateProvider
  candidates: null

  constructor: (editor, pattern) ->
    @candidates = @buildCandidates editor, pattern

  getCandidates: ->
    @candidates

  buildCandidates: (editor, pattern) ->
    matches = []
    editor.scan pattern, ({range, matchText}) =>
      matches.push new Match(editor, {range, matchText})
    matches

  destroy: ->
    for match in @candidates
      match.destroy()
    @candidates = null
