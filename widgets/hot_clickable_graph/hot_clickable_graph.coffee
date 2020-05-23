class Dashing.HotClickableGraph extends Dashing.Widget
  redirect: ->
    link = $(@node).find(".link")
    window.open(
      @link,
      '_blank'
    );

  @accessor 'current', ->
    return @get('displayedValue') if @get('displayedValue')
    points = @get('points')
    if points
      points[points.length - 1].y

  buckets: ->
    buckets = [0, 1, 2, 3, 4]
    buckets.reverse() if @cool > @warm
    buckets

  ready: ->
    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    @graph = new Rickshaw.Graph(
      element: @node
      width: width
      height: height
      renderer: @get("graphtype")
      series: [
        {
        color: "#fff",
        data: [{x:0, y:0}]
        }
      ]
      padding: {top: 0.02, left: 0.02, right: 0.02, bottom: 0.02}
    )

    @graph.series[0].data = @get('points') if @get('points')

    x_axis = new Rickshaw.Graph.Axis.Time(graph: @graph)
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, tickFormat: Rickshaw.Fixtures.Number.formatKMBT)
    @graph.render()

  onData: (data) ->
    $node = $(@node)

    value = parseInt (@get('current'))
    cool = parseInt @cool
    warm = parseInt @warm

    low = Math.min(cool, warm)
    high = Math.max(cool, warm)

    level = switch
      when value <= low then 0
      when value >= high then 4
      else 
        bucketSize = (high - low) / 3 # Total # of colours in middle
        Math.ceil (value - low) / bucketSize
  
    accurate_level = @buckets()[level]

    backgroundClass = "hotness#{accurate_level}"
    lastClass = @get "lastClass"
    $node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
    
    if @graph
      @graph.series[0].data = data.points
      @graph.render()

