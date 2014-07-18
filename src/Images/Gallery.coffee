Gallery =
  init: ->
    return if g.BOARD is 'f' or !Conf['Gallery']

    el = $.el 'a',
      href: 'javascript:;'
      id:   'appchan-gal'
      title: 'Gallery'
      className: 'fa'
      textContent: '\uf03e'

    $.on el, 'click', @cb.toggle

    Header.addShortcut el, true

    Post.callbacks.push
      name: 'Gallery'
      cb:   @node

  node: ->
    return unless @file
    if Gallery.nodes
      Gallery.generateThumb $ '.file', @nodes.root
      Gallery.nodes.total.textContent = Gallery.images.length

    unless Conf['Image Expansion']
      $.on @file.thumb.parentNode, 'click', Gallery.cb.image

  build: (image) ->
    Gallery.images  = []
    nodes = Gallery.nodes = {}

    nodes.el = dialog = $.el 'div',
      id: 'a-gallery'
      innerHTML: """
        <div class=gal-viewport>
          <span class=gal-buttons>
            <a class="menu-button" href="javascript:;"><i></i></a>
            <a href=javascript:; class=gal-close>×</a>
          </span>
          <a class=gal-name target="_blank"></a>
          <span class=gal-count>
            <span class='count'></span> / <span class='total'></span>
          </span>
          <div class=gal-prev></div>
          <div class=gal-image>
            <a href=javascript:;><img></a>
          </div>
          <div class=gal-next></div>
        </div>
        <div class=gal-thumbnails></div>
      """

    nodes[key] = $ value, dialog for key, value of {
      frame:   '.gal-image'
      name:    '.gal-name'
      count:   '.count'
      total:   '.total'
      thumbs:  '.gal-thumbnails'
      next:    '.gal-image a'
      current: '.gal-image img'
    }

    menuButton = $ '.menu-button', dialog
    nodes.menu = new UI.Menu()

    {cb} = Gallery
    $.on nodes.frame,             'click', cb.blank
    $.on nodes.next,              'click', cb.advance
    $.on $('.gal-prev',  dialog), 'click', cb.prev
    $.on $('.gal-next',  dialog), 'click', cb.next
    $.on $('.gal-close', dialog), 'click', cb.close

    $.on menuButton, 'click', (e) ->
      nodes.menu.toggle e, @, g

    {createSubEntry} = Gallery.menu
    for name of Config.gallery
      {el} = createSubEntry name

      nodes.menu.addEntry
        el: el
        order: 0

    $.on  d, 'keydown', cb.keybinds
    $.off d, 'keydown', Keybinds.keydown
    Gallery.generateThumb file for file, i in $$ '.post .file' when !$ '.fileDeletedRes, .fileDeleted', file
    $.add d.body, dialog

    nodes.thumbs.scrollTop = 0
    nodes.current.parentElement.scrollTop = 0

    Gallery.cb.open.call if image
      $ "[href='#{image.href.replace /https?:/, ''}']", nodes.thumbs
    else
      Gallery.images[0]

    d.body.style.overflow = 'hidden'
    nodes.total.textContent = i

  generateThumb: (file) ->
    post  = Get.postFromNode file
    return unless post.file and (post.file.isImage or post.file.isVideo or Conf['PDF in Gallery'])
    title = ($ '.fileText a', file).textContent

    thumb = $.el 'a',
      className: 'gal-thumb'
      href:      post.file.URL
      target:    '_blank'
      title:     title

    thumb.dataset.id      = Gallery.images.length
    thumb.dataset.post    = post.fullID
    thumb.dataset.isVideo = true if post.file.isVideo

    thumbImg = post.file.thumb.cloneNode false
    thumbImg.style.cssText = ''
    $.add thumb, thumbImg

    $.on thumb, 'click', Gallery.cb.open

    Gallery.images.push thumb
    $.add Gallery.nodes.thumbs, thumb

  cb:
    keybinds: (e) ->
      return unless key = Keybinds.keyCode e

      cb = switch key
        when 'Esc', Conf['Open Gallery']
          Gallery.cb.close
        when 'Right'
          Gallery.cb.next
        when 'Enter'
          Gallery.cb.advance
        when 'Left', ''
          Gallery.cb.prev

      return unless cb
      e.stopPropagation()
      e.preventDefault()
      cb()

    open: (e) ->
      e.preventDefault() if e
      return unless @

      {nodes} = Gallery
      {name}  = nodes

      $.rmClass  el, 'gal-highlight' if el = $ '.gal-highlight', nodes.thumbs
      $.addClass @,  'gal-highlight'

      elType = if @dataset.isVideo then 'video' else if /\.pdf$/.test(@href) then 'iframe' else 'img'
      $[if elType is 'iframe' then 'addClass' else 'rmClass'] nodes.el, 'gal-pdf'

      file = $.el elType,
        src:   name.href     = @href
        title: name.download = name.textContent = @title

      $.extend  file.dataset,   @dataset
      nodes.current.pause?()
      $.replace nodes.current,  file
      Video.configure file if @dataset.isVideo
      nodes.count.textContent = +@dataset.id + 1
      nodes.current           = file
      nodes.frame.scrollTop   = 0
      nodes.next.focus()
      
      # Scroll to post
      if Conf['Scroll to Post'] and post = (post = g.posts[file.dataset.post])?.nodes.root
        Header.scrollTo post

      $.on file, 'error', ->
        Gallery.cb.error file, thumb

      # Scroll
      rect  = @getBoundingClientRect()
      {top} = rect
      if top > 0
        top += rect.height - doc.clientHeight
        return if top < 0

      nodes.thumbs.scrollTop += top

    image: (e) ->
      e.preventDefault()
      e.stopPropagation()
      Gallery.build @

    error: (img, thumb) ->
      post = Get.postFromLink $.el 'a', href: img.dataset.post
      delete post.file.fullImage

      src = @src.split '/'
      if src[2] is 'i.4cdn.org'
        URL = Redirect.to 'file',
          boardID:  src[3]
          filename: src[src.length - 1]
        if URL
          thumb.href = URL
          return unless Gallery.nodes.current is img
          img.src = URL
          return
        if g.DEAD or post.isDead or post.file.isDead
          return

      # XXX CORS for i.4cdn.org WHEN?
      $.ajax "//a.4cdn.org/#{post.board}/thread/#{post.thread}.json", onload: ->
        return if @status isnt 200
        i = 0
        {posts} = @response
        while postObj = posts[i++]
          break if postObj.no is post.ID
        unless postObj.no
          return post.kill()
        if postObj.filedeleted
          post.kill true

    prev:      ->
      Gallery.cb.open.call(
        Gallery.images[+Gallery.nodes.current.dataset.id - 1] or Gallery.images[Gallery.images.length - 1]
      )
    next:      ->
      Gallery.cb.open.call(
        Gallery.images[+Gallery.nodes.current.dataset.id + 1] or Gallery.images[0]
      )
    toggle:    -> (if Gallery.nodes then Gallery.cb.close else Gallery.build)()
    blank: (e) -> Gallery.cb.close() if e.target is @

    advance: ->
      if Gallery.nodes.current.controls then return
      if Gallery.nodes.current.paused   then return Gallery.nodes.current.play()
      Gallery.cb.next()
    
    pause: ->
      {current} = Gallery.nodes
      current[if current.paused then 'play' else 'pause']() if current.nodeType is 'VIDEO'

    close: ->
      Gallery.nodes.current.pause?()
      $.rm Gallery.nodes.el
      delete Gallery.nodes
      d.body.style.overflow = ''

      $.off d, 'keydown', Gallery.cb.keybinds
      $.on  d, 'keydown', Keybinds.keydown

    setFitness: ->
      (if @checked then $.addClass else $.rmClass) doc, "gal-#{@name.toLowerCase().replace /\s+/g, '-'}"

  menu:
    init: ->
      return if !Conf['Gallery']

      el = $.el 'span',
        textContent: 'Gallery'
        className: 'gallery-link'

      {createSubEntry} = Gallery.menu
      subEntries = []
      for name of Config.gallery
        subEntries.push createSubEntry name

      Header.menu.addEntry
        el: el
        order: 105
        subEntries: subEntries

    createSubEntry: (name) ->
      label = $.el 'label',
        innerHTML: "<input type=checkbox name='#{name}'> #{name}"
      input = label.firstElementChild
      if name in ['Fit Width', 'Fit Height', 'Hide Thumbnails']
        $.on input, 'change', Gallery.cb.setFitness
      input.checked = Conf[name]
      $.event 'change', null, input
      $.on input, 'change', $.cb.checked
      el: label
