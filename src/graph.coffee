poly = @poly || {}

# Graph Object
class Graph
  constructor: (spec) ->
    @handlers = []
    @layers = null
    @scaleSet = null
    @axes = null
    @legends = null
    @dims = null
    @paper = null
    @coord = spec.coord ? poly.coord.cartesian()
    @initial_spec = spec
    @make spec, true

  reset : () => @make @initial_spec

  make: (spec, first=false) ->
    spec ?= @initial_spec
    @spec = spec
    # creation of layers
    spec.layers ?= []
    @layers ?= @_makeLayers @spec
    # subscribe to changes to data
    if first
      dataChange = @handleEvent 'data'
      for layerObj, id in @layers
        spec.layers[id].data.subscribe dataChange # changes to data
    # callback after data processing
    merge = _.after(@layers.length, @merge)
    for layerObj, id in @layers
      layerObj.make spec.layers[id], merge

  merge: () =>
    # make the scales...?
    domains = @_makeDomains @spec, @layers
    @scaleSet ?= @_makeScaleSet @spec, domains
    @scaleSet.make @spec.guides, domains, @layers
    # dimension calculation
    if not @dims
      @dims = @_makeDimensions @spec, @scaleSet
      @coord.make @dims
      @ranges = @coord.ranges()
    @scaleSet.setRanges @ranges
    @_legacy(domains)

    # render : (dom) =>
    if @spec.dom
      dom = @spec.dom
      scales = @scaleSet.scales
      @coord.setScales scales
      @paper ?= @_makePaper dom, @dims.width, @dims.height, @handleEvent
      clipping = @coord.clipping @dims
      # render each layer
      renderer = poly.render @handleEvent, @paper, scales, @coord, true, clipping
      for layer in @layers
        layer.render renderer
      # render axes
      renderer = poly.render @handleEvent, @paper, scales, @coord, false

      @scaleSet.makeAxes()
      @scaleSet.renderAxes @dims, renderer
      @scaleSet.makeLegends()
      @scaleSet.renderLegends @dims, renderer

  addHandler : (h) -> @handlers.push h
  removeHandler: (h) ->
    @handlers.splice _.indexOf(@handlers, h), 1

  handleEvent : (type) =>
    # POSSIBLE EVENTS: select, click, mover, mout, data
    graph = @
    handler = (params) ->
      obj = @
      if type == 'select'
        {start, end} = params
        obj.evtData = graph.scaleSet.fromPixels start, end
      else if type == 'data'
        obj.evtData = {}
      else
        obj.evtData = obj.data('e')

      for h in graph.handlers
        if _.isFunction(h)
          h(type, obj)
        else
          h.handle(type, obj)
    _.throttle handler, 1000

  _makeLayers: (spec) ->
    _.map spec.layers, (layerSpec) -> poly.layer.make(layerSpec, spec.strict)
  _makeDomains: (spec, layers) ->
    spec.guides ?= {}
    poly.domain.make layers, spec.guides, spec.strict
  _makeScaleSet: (spec, domains) ->
    @coord.make poly.dim.guess(spec)
    tmpRanges = @coord.ranges()
    poly.scale.make tmpRanges, @coord
  _makeDimensions: (spec, scaleSet) ->
    poly.dim.make spec, scaleSet.makeAxes(), scaleSet.makeLegends()
  _makePaper: (dom, width, height, handleEvent) ->
    paper = poly.paper document.getElementById(dom), width, height, handleEvent

  _legacy: (domains) =>
    # LEGACY: tick calculation
    @domains = domains
    @scales = @scaleSet.scales
    axes = @scaleSet.makeAxes()
    @ticks = {}
    for k, v of axes
      @ticks[k] = v.ticks

poly.chart = (spec) -> new Graph(spec)

@poly = poly
