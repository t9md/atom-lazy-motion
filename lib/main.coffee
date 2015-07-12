{CompositeDisposable, Range, Point} = require 'atom'
_ = require 'underscore-plus'
{filter} = require 'fuzzaldrin'
settings = require './settings'

Match = null

module.exports =
  subscriptions: null
  config: settings.config
  candidates: null

  activate: ->
    Match = require './match'
    @searchHistory = []
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'rapid-motion:forward':  => @start 'forward'
      'rapid-motion:backward': => @start 'backward'

  deactivate: ->
    @searchHistory = null
    @subscriptions.dispose()
    @cancel()

  start: (direction) ->
    ui = @getUI()
    unless ui.isVisible()
      @init()
      ui.setDirection direction
      ui.focus()
    else
      ui.setDirection direction
      return unless @matches.length
      unless (@lastDirection is direction and not @lastCurrent)
        # This mean last search was 'backward' and not found for backward direction.
        # Adjusting index make first entry(index=0) current.
        if direction is 'forward' and not @lastCurrent
          @index -= 1
      @updateCurrent @matches[@updateIndex(direction)]
      ui.refresh()

  init: ->
    @matchCursor = null
    # if @candidates
    #   # [TODO] remove this after word tokenization moved to observeTextEditors()
    #   # Last time's defered destroy() might not finished.
    #   for match in @candidates
    #     match.destroy()
    # @candidates = []
    @editor = atom.workspace.getActiveTextEditor()
    @editorState = @getEditorState @editor

  getCandidates: ->
    pattern = /[\w-.]+/g
    @scan(@editor, pattern)

  scan: (editor, pattern) ->
    matches = []
    editor.scan pattern, ({range, matchText}) =>
      matches.push new Match(editor, {range, matchText, class: 'rapid-motion-unmatch'})
    matches

  search: (direction, text) ->
    # [TODO] move to ovserveTextEditors
    @candidates ?= @getCandidates()
    for match in @matches ? []
      match.decorate 'rapid-motion-unmatch'
    return unless text

    @matches = filter @candidates, text, key: 'matchText'
    return unless @matches.length

    for match in @matches
      match.decorate 'rapid-motion-found'

    @matchCursor ?= @getMatchCursor()
    @matches = _.sortBy @matches, (match) ->
      match.getScore()
    @index = _.sortedIndex @matches, @matchCursor, (match) ->
      match.getScore()

    if @isExceedingBoundry(direction)
      console.log "Exceeding"
    else
      console.log "not Exceeding"
      @index -= 1 if direction is 'backward'
      @scrollToMatch @matches[@index]

  isExceedingBoundry: (direction) ->
    switch direction
      when 'forward'
        @index is @matches.length
      when 'backward'
        @index is 0

  updateCurrent: (match) ->
    @lastCurrent?.decorate 'rapid-motion-found'
    match.decorate 'rapid-motion-found current'
    unless @lastCurrent?.start.isEqual(match.start)
      match.flash()
    match.scroll()
    @lastCurrent = match

  scrollToMatch: (match) ->
    match.decorate 'rapid-motion-found current'
    match.flash()
    match.scroll()

  getMatchCursor: ->
    start = @editor.getCursorBufferPosition()
    end = start.translate([0, 1])
    range = new Range(start, end)
    match = new Match(@editor, {range})
    match.decorate 'rapid-motion-cursor'
    match

  cancel: ->
    @setEditorState @editor, @editorState if @editorState?
    @editorState = null
    @matchCursor?.destroy()
    @matchCursor = null
    @lastCurrent = null
    @reset()

  land: ->
    @matches?[@index]?.land()
    @matchCursor?.destroy()
    @matchCursor = null
    @reset()

  reset: ->
    @index = 0
    # _.defer =>
    for match in @candidates ? []
      match.destroy()
    @candidates = null
    @matches = []

  updateIndex: (direction) ->
    @index =
      if direction is 'forward'
        Math.min(@matches.length-1, @index+1)
      else
        Math.max(0, @index-1)
    @index

  getUI: ->
    @ui ?= (
      ui = new (require './ui')
      ui.initialize this
      ui)

  # Accessed from UI
  # -------------------------
  getCount: ->
    if 0 < @index < @matches.length
      { total: @matches.length, current: @index+1 }
    else
      { total: @matches.length, current: 0 }


  # Utility
  # -------------------------
  getEditorState: (editor) ->
    scrollTop: editor.getScrollTop()

  setEditorState: (editor, {scrollTop}) ->
    editor.setScrollTop scrollTop
