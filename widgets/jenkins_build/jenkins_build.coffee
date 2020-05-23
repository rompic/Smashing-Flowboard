class Dashing.JenkinsBuild extends Dashing.Widget
  redirect: ->
    link = $(@node).find(".link")
    window.open(
      @link,
      '_blank'
    ); 

  @accessor 'value', Dashing.AnimatedValue
  @accessor 'bgColor', ->
    if @get('currentResult') == "SUCCESS"
      "#96bf48"
    else if @get('currentResult') == "FAILURE"
      "#D26771"
    else if @get('currentResult') == "PREBUILD"
      "#ff9618"
    else if @get('currentResult') == "UNSTABLE"
      "#ff9618"
    else
      "#999"

  constructor: ->
    super
    @observe 'value', (value) ->
      $(@node).find(".jenkins-build").val(value).trigger('change')

  ready: ->
    meter = $(@node).find(".jenkins-build")
    meter.attr("data-bgcolor", meter.css("background-color"))
    meter.attr("data-fgcolor", meter.css("color"))
    meter.knob()

  onData: (data) ->
    if data.currentResult isnt data.lastResult
      $(@node).fadeOut().css('background-color', @get('bgColor')).fadeIn()
    else
      $(@node).css('background-color', @get('bgColor'))
