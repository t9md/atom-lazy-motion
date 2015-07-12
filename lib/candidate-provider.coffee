{CompositeDisposable, Range} = require 'atom'
_ = require 'underscore-plus'
Match = require './match'

module.exports =
class CandidateProvider
  candidates: null

  constructor: (@editor, @wordPattern) ->
    @candidates = @buildCandidates()

  getCandidates: ->
    @candidates

  dump: ->
    console.log @candidates.map (c) -> c.matchText

  buildCandidates: ->
    matches = []
    @editor.scan @wordPattern, ({range, matchText}) =>
      matches.push new Match(@editor, {range, matchText, class: 'rapid-motion-unmatch'})
    matches

  destroy: ->
    for match in @candidates
      match.destroy()
    @candidates = null
