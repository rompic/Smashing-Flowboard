class Dashing.BarChart extends Dashing.Widget
  redirect: ->
    link = $(@node).find(".link")
    window.open(
      @link,
      '_blank'
    ); 

  ready: ->
    # Margins: zero if not set or the same as the opposite margin
    # (you likely want this to keep the chart centered within the widget)
    left = @get('leftMargin') || 0
    right = @get('rightMargin') || left
    top = @get('topMargin') || 0
    bottom = @get('bottomMargin') || top

    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1) - left - right
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey")) - 35 - top - bottom

    # Lower the chart's height to make space for moreinfo if not empty
    if !!@get('moreinfo')
      height -= 20

    $holder = $("<div class='canvas-holder' style='left:#{left}px; top:#{top}px; position:absolute;'></div>")
    $(@node).append $holder

    canvas = $(@node).find('.canvas-holder')
    canvas.append("<canvas width=\"#{width}\" height=\"#{height}\" class=\"chart-area\"/>")

    @ctx = $(@node).find('.chart-area')[0].getContext('2d')

    @myChart = new Chart(@ctx, {
      type: 'bar'
      data: {
        labels: @get('labels')
        datasets: @get('datasets')
      }
      options: $.extend({
        responsive: true
        maintainAspectRatio: true
        legend: {
          display: true
        }
      }, @get('options'))
    });

  onData: (data) ->
    # Load new values and update chart
    if @myChart
      if data.labels then @myChart.data.labels = data.labels
      if data.datasets then @myChart.data.datasets = data.datasets
      if data.options then $.extend(@myChart.options, data.options)

      @myChart.update()
