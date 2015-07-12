{CompositeDisposable, Range} = require 'atom'
_ = require 'underscore-plus'
Match = require './match'

module.exports =
class CandidateProvider
  candidates: null

  constructor: (@editor, @wordPattern) ->
    @candidates = null
    @addCandidatesForRange @getAllRange()
    # console.log [@editor.getURI(), @candidates.length]
    # @editorSubscriptions = subs = new CompositeDisposable
    # @observeBuffer @editor.getBuffer()

  observeBuffer: (buffer) ->
    onDidSave = =>
      @addCandidatesForRange @getAllRange()
      # console.log 'saved! rebuild candidate finish!'

    onWillChange = ({oldRange}) =>
      range = new Range([oldRange.start.row, 0], [oldRange.end.row, Infinity])
      @removeCandidatesForRange range

    onDidChange = ({newRange}) =>
      range = new Range([newRange.start.row, 0], [newRange.end.row, Infinity])
      @addCandidatesForRange range

    subs = @editorSubscriptions
    subs.add buffer.onWillChange(onWillChange)
    subs.add buffer.onDidChange(onDidChange)
    subs.add buffer.onDidSave(onDidSave)

  getCandidates: ->
    @candidates

  resetCandidates: ->
    for match in @candidates ? []
      match.decorate 'rapid-motion-unmatch'
    # console.log 'called resetCandidates'

  dump: ->
    console.log @candidates.map (c) -> c.matchText

  getAllRange: ->
    new Range([0, 0], [@editor.getLastBufferRow(), Infinity])

  buildCandidates: ->
    range = [[0, 0], [@editor.getLastBufferRow(), Infinity]]
    @addCandidatesForRange range

  addCandidatesForRange: (range) ->
    # console.log '# adding!'
    # console.log "len-before: #{@candidates?.length}"
    matches = []
    @editor.scanInBufferRange @wordPattern, range, ({range, matchText}) =>
      matches.push new Match(@editor, {range, matchText, class: 'rapid-motion-unmatch'})
    @candidates = matches
    # console.log "len-after: #{@candidates.length}"

  removeCandidatesForRange: (range) ->
    # console.log '# removing!'
    # console.log "len-before: #{@candidates.length}"
    @candidates = _.reject @candidates, (m) =>
      range.containsRange(m.range)
    # console.log "len-after: #{@candidates.length}"

  destroy: ->
    for match in @candidates
      match.destroy()
