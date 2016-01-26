module.exports =
  scope: 'lazy-motion'

  notifyAndRemoveDeprecate: (params...) ->
    deprecatedParams = (param for param in params when @has(param))
    return if deprecatedParams.length is 0

    content = [
      "#{@scope}: Config options deprecated.  ",
      "Automatically removed from your `connfig.cson`  "
    ]
    for param in deprecatedParams
      @delete(param)
      content.push "- `#{param}`"
    atom.notifications.addWarning content.join("\n"), dismissable: true

  has: (param) ->
    param of atom.config.get(@scope)

  delete: (param) ->
    @set(param, undefined)

  get: (param) ->
    atom.config.get("#{@scope}.#{param}")

  set: (param, value) ->
    atom.config.set("#{@scope}.#{param}", value)
