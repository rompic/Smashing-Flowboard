class Dashing.HotClickableNumber extends Dashing.Widget
  redirect: ->
    link = $(@node).find(".link")
    window.open(
      @link,
      '_blank'
    ); 

  @accessor 'current', Dashing.AnimatedValue

  @accessor 'difference', ->
    if @get('last')
      last = parseInt(@get('last'))
      current = parseInt(@get('current'))
      if last != 0
        diff = Math.abs(Math.round((current - last) / last * 100))
        "#{diff}%"
    else
      ""

  @accessor 'arrow', ->
    if @get('last')
      if parseInt(@get('current')) > parseInt(@get('last')) then 'fa fa-arrow-up' else 'fa fa-arrow-down'

  buckets: ->
    buckets = [0, 1, 2, 3, 4]
    buckets.reverse() if @cool > @warm
    buckets

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"
    node = $(@node)
    value = parseInt data.current
    @cool = parseInt node.data "cool"
    @warm = parseInt node.data "warm"

    low = Math.min(@cool, @warm)
    high = Math.max(@cool, @warm)

    level = switch
      when value <= low then 0
      when value >= high then 4
      else
        bucketSize = (high - low) / 3 # Total # of colours in middle
        Math.ceil (value - low) / bucketSize

    accurate_level = @buckets()[level]

    backgroundClass = "hotness#{accurate_level}"
    lastClass = @get "lastClass"
    node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
