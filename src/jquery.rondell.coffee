###!
  jQuery rondell plugin
  @name jquery.rondell.js
  @author Sebastian Helzle (sebastian@helzle.net or @sebobo)
  @version 0.8.4
  @date 12/21/2011
  @category jQuery plugin
  @copyright (c) 2009-2011 Sebastian Helzle (www.sebastianhelzle.net)
  @license Licensed under the MIT (http://www.opensource.org/licenses/mit-license.php) license.
###

(($) ->
  ### Global rondell plugin properties ###
  $.rondell =
    version: '0.8.4'
    name: 'rondell'
    defaults:
      showContainer: true       # When the plugin has finished initializing $.show() will be called on the items container
      resizeableClass: 'resizeable'
      smallClass: 'itemSmall'
      hiddenClass: 'itemHidden'
      currentLayer: 0           # Active layer number in a rondell instance
      container: null           # Container object wrapping the rondell items
      radius:                   # Radius for the default circle function
        x: 300 
        y: 50  
      center:                   # Center where the focused element is displayed
        left: 400 
        top: 200
      size:                     # Defaults to center * 2 on init
        width: null
        height: null
      visibleItems: 'auto'      # How many items should be visible in each direction
      scaling: 2                # Size of focused element
      opacityMin: 0.05          # Min opacity before elements are set to display: none
      fadeTime: 300
      zIndex: 1000              # All elements of the rondell will use this z-index and add their depth to it
      itemProperties:           # Default properties for each item
        delay: 100              # Time offset between the animation of each item
        cssClass: 'rondellItem' # Identifier for each item
        size: 
          width: 150
          height: 150
        sizeFocused:
          width: 0
          height: 0
      repeating: true           # Will show first item after last item and so on
      alwaysShowCaption: false  # Don't hide caption on mouseleave
      autoRotation:             # If the cursor leaves the rondell continue spinning
        enabled: false
        paused: false           # Can be used to pause the auto rotation with a play/pause button for example 
        _timer: -1              
        direction: 0            # 0 or 1 means left and right
        once: false             # Will animate until the rondell will be hovered at least once
        delay: 5000
      controls:                 # Buttons to control the rondell
        enabled: true
        fadeTime: 400           # Show/hide animation speed
        margin:     
          x: 20                 # Distance from left and right edge of the container
          y: 20                 # Distance from top and bottom edge of the container
      strings: # String for the controls 
        prev: 'prev'
        next: 'next'
      touch:
        enabled: true
        preventDefaults: true   # Will call event.preventDefault() on touch events
        threshold: 100          # Distance in pixels the "finger" has to swipe to create the touch event
        _start: undefined        
        _end: undefined         
      funcEase: 'easeInOutQuad' # jQuery easing function name for the movement of items
      theme: 'default'          # CSS theme class which gets added to the rondell container
      preset: ''                # Configuration preset
      effect: null              # Special effect function for the focused item, not used currently
  
  ### Add default easing function for rondell to jQuery if missing ###
  unless $.easing.easeInOutQuad        
    $.easing.easeInOutQuad = (x, t, b, c, d) ->
      if ((t/=d/2) < 1) then c/2*t*t + b else -c/2 * ((--t)*(t-2) - 1) + b
   
  # Rondell class holds all rondell items and functions   
  class Rondell
    @rondellCount: 0            # Globally stores the number of rondells for uuid creation
    @activeRondell: null        # Globally stores the last activated rondell for keyboard interaction
    
    constructor: (options, numItems, initCallback=undefined) ->
      @id = Rondell.rondellCount++
      @items = [] # Holds the items
      @maxItems = numItems
      @loadedItems = 0
      @initCallback = initCallback
      
      # Update rondell properties with new options
      if options?.preset of $.rondell.presets
        $.extend(true, @, $.rondell.defaults, $.rondell.presets[options.preset], options or {})
      else
        $.extend(true, @, $.rondell.defaults, options or {})
        
      @itemProperties.sizeFocused =
        width: @itemProperties.sizeFocused.width or @itemProperties.size.width * @scaling
        height: @itemProperties.sizeFocused.height or @itemProperties.size.height * @scaling
        
      @size = 
        width: @size.width or @center.left * 2
        height: @size.height or @center.top * 2
    
    # Animation functions, can be different for each rondell
    funcLeft: (layerDiff, rondell) ->
      rondell.center.left - rondell.itemProperties.size.width / 2.0 + Math.sin(layerDiff) * rondell.radius.x
    funcTop: (layerDiff, rondell) ->
      rondell.center.top - rondell.itemProperties.size.height / 2.0 + Math.cos(layerDiff) * rondell.radius.y
    funcDiff: (layerDiff, rondell) ->
      Math.pow(Math.abs(layerDiff) / rondell.maxItems, 0.5) * Math.PI
    funcOpacity: (layerDist, rondell) ->
      if rondell.visibleItems > 1 then Math.max(0, 1.0 - Math.pow(layerDist / rondell.visibleItems, 2)) else 0
    funcSize: (layerDist, rondell) ->
      1
    
    showCaption: (layerNum) => 
      # Restore automatic height and show caption
      $('.rondellCaption.overlay', @_getItem(layerNum).object)
      .css(
        height: 'auto'
        overflow: 'auto'
      ).stop(true).fadeTo(300, 1)
      
    hideCaption: (layerNum) =>
      # Fix height before hiding the caption to avoid jumping text when the item changes its size
      caption = $('.rondellCaption.overlay:visible', @_getItem(layerNum).object) 
      caption.css(
        height: caption.height()
        overflow: 'hidden'
      ).stop(true).fadeTo(200, 0)
      
    _getItem: (layerNum) =>
      @items[layerNum - 1]
      
    _initItem: (layerNum, item) =>
      @items[layerNum - 1] = item
      
      # Wrap other content as overlay caption
      captionContent = item.icon?.siblings()
      if not (captionContent?.length or item.icon) and item.object.children().length
        captionContent = item.object.children()
        
      # Or use title/alt texts as overlay caption
      if not captionContent.length 
        caption = item.object.attr('title') or item.icon?.attr('alt') or item.icon?.attr('title')  
        if caption
          captionContent = $("<p>#{caption}</p>")
          item.object.append(captionContent)

      # Create overlay from caption if found
      if captionContent.length
        captionContainer = $('<div class="rondellCaption"></div>')
        captionContainer.addClass('overlay') if item.icon
        captionContent.wrapAll(captionContainer)
        
      # Init click events
      item.object
      .addClass("rondellItemNew #{@itemProperties.cssClass}")
      .css(
        opacity: 0
        width: item.sizeSmall.width
        height: item.sizeSmall.height
        left: @center.left - item.sizeFocused.width / 2
        top: @center.top - item.sizeFocused.height / 2
      )
      .bind('mouseover mouseout click', (e) =>
        switch e.type
          when 'mouseover'
            item.object.addClass('rondellItemHovered') if item.object.is(':visible') and not item.hidden
          when 'mouseout'
            item.object.removeClass('rondellItemHovered')
          when 'click'
            if item.object.is(':visible') and not (@currentLayer is layerNum or item.hidden)
              @shiftTo(layerNum)
              e.preventDefault()
      )
      
      @loadedItems += 1
      
      @_start() if @loadedItems is @maxItems
      
    _onloadItem: (itemIndex, obj, copy=undefined) =>
      icon = $('img:first', obj)
      
      isResizeable = icon.hasClass(@resizeableClass)
      layerNum = itemIndex
    
      itemSize = @itemProperties.size
      focusedSize = @itemProperties.sizeFocused
      scaling = @scaling
      
      # create size vars for the small and focused size
      foWidth = smWidth = copy?.width() || copy?[0].width || icon[0].width || icon.width()
      foHeight = smHeight = copy?.height() || copy?[0].height || icon[0].height || icon.height()
      
      # Delete copy, not needed anymore
      copy?.remove()
      
      # Return if width and height can't be resolved
      return unless smWidth and smHeight
    
      if isResizeable
        if smWidth >= smHeight
          # compute smaller side length
          smHeight *= itemSize.width / smWidth
          foHeight *= focusedSize.width / foWidth
          # compute full size length
          smWidth = itemSize.width
          foWidth = focusedSize.width
        else
          # compute smaller side length
          smWidth *= itemSize.height / smHeight
          foWidth *= focusedSize.height / foHeight
          # compute full size length
          smHeight = itemSize.height
          foHeight = focusedSize.height
      else
        # scale to given sizes
        smWidth = itemSize.width
        smHeight = itemSize.height
        foWidth = focusedSize.width
        foHeight = focusedSize.height
        
      # Set vars in item array
      @_initItem(layerNum, 
        object: obj 
        icon: icon
        small: false 
        hidden: false
        resizeable: isResizeable
        sizeSmall: 
          width: smWidth
          height: smHeight
        sizeFocused: 
          width: foWidth
          height: foHeight
      )
      
    _loadItem: (itemIndex, obj) =>
      icon = $('img:first', obj)
      if icon[0].complete and icon[0].width
        # Image is already loaded (i.e. from cache)
        @_onloadItem(itemIndex, obj) 
      else 
        # Create copy of the image and wait for the copy to load to get the real dimensions
        copy = $("<img style=\"display:none\"/>")
        $('body').append(copy)
        copy.one("load", =>
          @_onloadItem(itemIndex, obj, copy)
        ).attr("src", icon.attr("src"))
      
    _start: =>
      # Set currentlayer to the middle item or leave it be if set before and index exists
      @currentLayer = Math.max(0, Math.min(@currentLayer or Math.round(@maxItems / 2), @maxItems))
      
      # Set visibleItems to half the maxItems if set to auto
      @visibleItems = Math.max(2, Math.floor(@maxItems / 2)) if @visibleItems is 'auto'
      
      # Create controls
      controls = @controls
      if controls.enabled
        shiftLeft = $('<a class="rondellControl rondellShiftLeft" href="#"/>').text(@strings.prev).click(@shiftLeft)
        .css(
          left: controls.margin.x
          top: controls.margin.y
          "z-index": @zIndex + @maxItems + 2
        )
          
        shiftRight = $('<a class="rondellControl rondellShiftRight" href="#/"/>').text(@strings.next).click(@shiftRight)
        .css(
          right: controls.margin.x
          top: controls.margin.y
          "z-index": @zIndex + @maxItems + 2
        )
          
        @container.append(shiftLeft, shiftRight)
        
        
      # Attach keydown event to document for each rondell instance
      $(document).keydown(@keyDown)
      
      # Add hover and touch functions to container
      @container.removeClass('initializing').bind('mouseover mouseout', @_hover).bind('touchstart touchmove touchend', @_touch)
      
      # Show items parent container
      @container.parent().show() if @showContainer
          
      # Fire callback with rondell instance if callback was provided
      @initCallback?(@)
      
      # Move items to starting positions
      @shiftTo(@currentLayer)
      
    _touch: (e) =>
      return unless @touch.enabled
      
      touch = e.originalEvent.touches[0] or e.originalEvent.changedTouches[0]
      
      switch e.type
        when 'touchstart'
          @touch._start = 
            x: touch.pageX
            y: touch.pageY
        when 'touchmove'
          e.preventDefault() if @touch.preventDefaults
          @touch._end =
            x: touch.pageX
            y: touch.pageY
        when 'touchend'
          if @touch._start and @touch._end
            changeX = @touch._end.x - @touch._start.x
            if Math.abs(changeX) > @touch.threshold
              if changeX > 0
                @shiftLeft()
              if changeX < 0
                @shiftRight()
              
            # Reset end position
            @touch._start = @touch._end = undefined
            
      true
      
    _hover: (e) =>      
      # Show or hide controls if they exist
      $('.rondellControl', @container).stop().fadeTo(@controls.fadeTime, if e.type is 'mouseover' then 1 else 0)
      
      # Start or stop auto rotation if enabled
      paused = @autoRotation.paused
      if e.type is 'mouseover'
        Rondell.activeRondell = @.id
        @hovering = true
        unless paused
          @autoRotation.paused = true
          @showCaption(@currentLayer)
      else
        @hovering = false
        if paused and not @autoRotation.once
          @autoRotation.paused = false
          @_autoShift()
        @hideCaption(@currentLayer) unless @alwaysShowCaption
      
    layerFadeIn: (layerNum) =>
      item = @_getItem(layerNum)
      item.small = false
      itemFocusedWidth = item.sizeFocused.width
      itemFocusedHeight = item.sizeFocused.height
      
      # Move item to center position and fade in
      item.object.stop(true).show(0)
      .css('z-index', @zIndex + @maxItems)
      .addClass('rondellItemFocused')
      .animate(
          width: itemFocusedWidth
          height: itemFocusedHeight
          left: @center.left - itemFocusedWidth / 2
          top: @center.top - itemFocusedHeight / 2
          opacity: 1
        , @fadeTime, @funcEase, =>
          @_autoShift()
          @showCaption(layerNum) if @hovering or @alwaysShowCaption
      )
      
      if item.icon and not item.resizeable
        margin = (@itemProperties.sizeFocused.height - item.icon.height()) / 2
        item.icon.stop(true).animate(
            marginTop: margin
            marginBottom: margin
          , @fadeTime)
          
    layerFadeOut: (layerNum) =>
      item = @_getItem(layerNum)
      
      layerDist = Math.abs(layerNum - @currentLayer)
      layerPos = layerNum
      
      # Find new layer position
      if layerDist > @visibleItems and @repeating
        if @currentLayer + @visibleItems > @maxItems
          layerPos += @maxItems
        else if @currentLayer - @visibleItems <= @maxItems
          layerPos -= @maxItems
        layerDist = Math.abs(layerPos - @currentLayer)

      # Get the absolute layer number difference
      layerDiff = @funcDiff(layerPos - @currentLayer, @)
      layerDiff *= -1 if layerPos < @currentLayer
      
      itemWidth = item.sizeSmall.width * @funcSize(layerDiff, @)
      itemHeight = item.sizeSmall.height * @funcSize(layerDiff, @)
      
      newX = @funcLeft(layerDiff, @) + (@itemProperties.size.width - itemWidth) / 2
      newY = @funcTop(layerDiff, @) + (@itemProperties.size.height - itemHeight) / 2
      
      newZ = @zIndex + (if layerDiff < 0 then layerPos else -layerPos)
      fadeTime = @fadeTime + @itemProperties.delay * layerDist
      isNew = item.object.hasClass('rondellItemNew')
        
      # Is item visible
      if isNew or layerDist <= @visibleItems
        @hideCaption(layerNum)
        
        newOpacity = @funcOpacity(layerDist, @)
        item.object.show() if newOpacity >= @opacityMin

        item.object.removeClass('rondellItemNew rondellItemFocused').stop(true)
        .css('z-index', newZ)
        .animate(
            width: itemWidth
            height: itemHeight
            left: newX
            top: newY
            opacity: newOpacity 
          , fadeTime, @funcEase, =>
            if item.object.css('opacity') < @opacityMin then item.object.hide() else item.object.show()
        )
        
        item.hidden = false
        unless item.small
          item.small = true
          if item.icon and not item.resizeable
            margin = (@itemProperties.size.height - item.icon.height()) / 2
            item.icon.stop(true).animate(
                marginTop: margin
                marginBottom: margin
              , fadeTime
            )
      else if item.hidden
        ### Update position even if out of view to fix animation when reappearing ###
        item.object.css(
          left: newX
          top: newY
          'z-index': newZ
        )
      else
        # Hide items which are moved out of view
        item.hidden = true
        item.object.stop(true)
        .css('z-index', newZ)
        .animate(
            opacity: 0
          , fadeTime / 2, @funcEase, =>
          @hideCaption(layerNum)
        )

    shiftTo: (layerNum) =>
      if @repeating 
        # Update current layer number if carousel reached it's limit
        if layerNum < 1 
          layerNum = @maxItems
        else if layerNum > @maxItems 
          layerNum = 1
      
      if layerNum > 0 and layerNum <= @maxItems
        @currentLayer = layerNum
        
        # Hide all layers except the current layer
        @layerFadeOut(i) for i in [1..@maxItems] when i isnt @currentLayer
        @layerFadeIn(@currentLayer)
         
    shiftLeft: (e) => 
      e?.preventDefault()
      @shiftTo(@currentLayer - 1) 
        
    shiftRight: (e) => 
      e?.preventDefault()
      @shiftTo(@currentLayer + 1) 
        
    _autoShift: =>
      autoRotation = @autoRotation
      if @isActive() and autoRotation.enabled and autoRotation._timer < 0
        # store timer id
        autoRotation._timer = window.setTimeout( =>
            @autoRotation._timer = -1
            if @isActive() and not autoRotation.paused
              if autoRotation.direction then @shiftRight() else @shiftLeft()
          , autoRotation.delay
        )
        
    isActive: ->
      true
    
    keyDown: (e) =>
      if @isActive() and Rondell.activeRondell is @.id
        # Clear current rotation timer on user interaction
        if @autoRotation._timer >= 0
          window.clearTimeout(@autoRotation._timer) 
          @autoRotation._timer = -1
          
        switch e.which
          # arrow left
          when 37 then @shiftLeft(e)
          # arrow right 
          when 39 then @shiftRight(e) 
          
  class DF1Filter
    ###!
      Direct Form 1 Filter
      Sample values for average inertia:
        t = 1/30 timestep
        m = 1 mass
        d = 0.5 damping
        c = 1 spring constant
        scaling = 40 scales the output
    ###

    constructor: (t, m , d, c, scaling) ->
      @t = t
      @m = m
      @d = d
      @c = c
      @scaling = scaling
    
      @a0 = 1 + 2 * d / c / t + 4 * m / c / (t * t)
      @a1 = (2 - 8 * m / c / (t * t)) / @a0
      @a2 = (1 - 2 * d / t / c + 4 * m / c / (t * t)) / @a0
    
      @b0 = 1 / @a0
      @b1 = 2 / @a0
      @b2 = 1 / @a0
    
      @x1 = @x2 = @y1 = @y2 = 0
  
    reset = (val) =>
      @x1 = @x2 = @y1 = @y2 = val
  
    getOutput = (x0) =>    
      output = @b0 * x0 + @b1 * @x1 + @b2 * @x2 - @a1 * @y1 - @a2 * @y2
      
      @x2 = @x1 
      @x1 = x0
      
      @y2 = @y1
      @y1 = output
  
      output * @scaling
  
  $.fn.rondell = (options={}, callback=undefined) ->
    # Create new rondell instance
    rondell = new Rondell(options, @length, callback)
    
    # Wrap elements in new container
    @wrapAll($('<div class="rondellContainer initializing"></div>'))
    
    # Set container size  
    rondell.container = @parent().css(rondell.size)
    
    rondell.container.addClass("rondellTheme_#{rondell.theme}")
          
    # Setup each item
    @each (idx) ->
      obj = $(@)
      itemIndex = idx + 1
      
      if $('img:first', obj).length
        rondell._loadItem(itemIndex, obj)
      else
        # Init item without an icon
        rondell._initItem(itemIndex, 
          object: obj 
          icon: null
          small: false 
          hidden: false
          resizeable: false
          sizeSmall: rondell.itemProperties.size
          sizeFocused: rondell.itemProperties.sizeFocused
        )
        
    # Return rondell instance
    rondell
    
)(jQuery) 
