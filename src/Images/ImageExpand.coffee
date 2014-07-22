ImageExpand =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Image Expansion']

    @EAI = $.el 'a',
      className: 'expand-all-shortcut fa fa-expand'
      textContent: 'EAI' 
      title: 'Expand All Images'
      href: 'javascript:;'
    $.on @EAI, 'click', ImageExpand.cb.toggleAll
    Header.addShortcut @EAI, 3

    Post.callbacks.push
      name: 'Image Expansion'
      cb: @node
  node: ->
    return unless @file?.isImage or @file?.isVideo
    {thumb} = @file
    $.on thumb.parentNode, 'click', ImageExpand.cb.toggle
    if @isClone 
      if $.hasClass thumb, 'expanding'
        # If we clone a post where the image is still loading,
        # make it loading in the clone too.
        ImageExpand.contract @
        ImageExpand.expand @

      else if @file.isExpanded and @file.isVideo
        clone = @
        ImageExpand.setupVideoControls clone
        unless clone.origin.file.fullImage.paused
          $.queueTask -> Video.start clone.file.fullImage

      return
    else if ImageExpand.on and !@isHidden and
      (Conf['Expand spoilers'] or !@file.isSpoiler) and
      (Conf['Expand videos'] or !@file.isVideo)
        ImageExpand.expand @, null, true
  cb:
    toggle: (e) ->
      return if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey or e.button isnt 0
      post = Get.postFromNode @
      return if post.file.isExpanded and post.file.fullImage?.controls
      e.preventDefault()
      ImageExpand.toggle post

    toggleAll: ->
      $.event 'CloseMenu'
      toggle = (post) ->
        {file} = post
        return unless file and (file.isImage or file.isVideo) and doc.contains post.nodes.root
        if ImageExpand.on and
          (!Conf['Expand spoilers'] and file.isSpoiler or
          !Conf['Expand videos']    and file.isVideo or
          Conf['Expand from here']  and Header.getTopOf(file.thumb) < 0)
            return
        $.queueTask func, post

      if ImageExpand.on = $.hasClass ImageExpand.EAI, 'expand-all-shortcut'
        ImageExpand.EAI.className = 'contract-all-shortcut fa fa-compress'
        ImageExpand.EAI.title     = 'Contract All Images'
        func = (post) -> ImageExpand.expand post, null, true
      else
        ImageExpand.EAI.className = 'expand-all-shortcut fa fa-expand'
        ImageExpand.EAI.title     = 'Expand All Images'
        func = ImageExpand.contract

      g.posts.forEach (post) ->
        toggle post for post in [post, post.clones...]
        return

    setFitness: ->
      (if @checked then $.addClass else $.rmClass) doc, @name.toLowerCase().replace /\s+/g, '-'

  toggle: (post) ->
    unless post.file.isExpanded or $.hasClass post.file.thumb, 'expanding'
      ImageExpand.expand post
      return

    # Scroll back to the thumbnail when contracting the image
    # to avoid being left miles away from the relevant post.
    {root} = post.nodes
    {top, left} = (if Conf['Advance on contract'] then do ->
      next = root
      while next = $.x "following::div[contains(@class,'postContainer')][1]", next
        continue if $('.stub', next) or next.offsetHeight is 0
        return next
      root
    else 
      root
    ).getBoundingClientRect()

    if top < 0
      y = top
      if Conf['Fixed Header'] and not Conf['Bottom Header']
        headRect = Header.bar.getBoundingClientRect()
        y -= headRect.top + headRect.height

    if left < 0
      x = -window.scrollX
    window.scrollBy x, y if x or y
    ImageExpand.contract post

  contract: (post) ->
    {thumb} = post.file
    if post.file.isVideo and video = post.file.fullImage
      video.pause()
      TrashQueue.add video, post
      thumb.parentNode.href   = video.src
      thumb.parentNode.target = '_blank'
      for eventName, cb of ImageExpand.videoCB
        $.off video, eventName, cb
      $.rm   post.file.videoControls
      delete post.file.videoControls
    $.rmClass post.nodes.root, 'expanded-image'
    $.rmClass thumb, 'expanding'
    delete post.file.isExpanded

  expand: (post, src, disableAutoplay) ->
    # Do not expand images of hidden/filtered replies, or already expanded pictures.
    {thumb, isVideo} = post.file
    return if post.isHidden or post.file.isExpanded or $.hasClass thumb, 'expanding'
    $.addClass thumb, 'expanding'
    el = post.file.fullImage or $.el (if isVideo then 'video' else 'img'), className: 'full-image'
    $.on el, 'error', ImageExpand.error
    if post.file.fullImage
      # Expand already-loaded/ing picture.
      TrashQueue.remove el
    else
      el.src = src or post.file.URL
      $.after thumb, el
      post.file.fullImage = el
    $.asap (-> if isVideo then el.readyState >= el.HAVE_CURRENT_DATA else el.naturalHeight), ->
      ImageExpand.completeExpand post, disableAutoplay

  completeExpand: (post, disableAutoplay) ->
    return unless $.hasClass post.file.thumb, 'expanding' # contracted before the image loaded
    unless post.nodes.root.parentNode
      # Image might start/finish loading before the post is inserted.
      # Don't scroll when it's expanded in a QP for example.
      ImageExpand.completeExpand2 post
      return
    {bottom} = post.nodes.root.getBoundingClientRect()
    $.queueTask ->
      ImageExpand.completeExpand2 post, disableAutoplay
      return unless bottom <= 0
      window.scrollBy 0, post.nodes.root.getBoundingClientRect().bottom - bottom

  completeExpand2: (post, disableAutoplay) ->
    $.addClass post.nodes.root, 'expanded-image'
    $.rmClass  post.file.thumb, 'expanding'
    post.file.isExpanded = true
    if post.file.isVideo
      ImageExpand.setupVideoControls post
      Video.configure post.file.fullImage, disableAutoplay

  videoCB: do ->
    # dragging to the left contracts the video
    mousedown = false
    mouseover:     -> mousedown = false
    mousedown: (e) -> mousedown = true  if e.button is 0
    mouseup:   (e) -> mousedown = false if e.button is 0
    mouseout:  (e) -> ImageExpand.contract(Get.postFromNode @) if mousedown and e.clientX <= @getBoundingClientRect().left
    click:     (e) ->
      if @paused and not @controls
        @play()
        e.stopPropagation()

  setupVideoControls: (post) ->
    {file}  = post
    video   = file.fullImage

    # disable link to file so native controls can work
    file.thumb.parentNode.removeAttribute 'href'
    file.thumb.parentNode.removeAttribute 'target'

    # setup callbacks on video element
    $.on video, eventName, cb for eventName, cb of ImageExpand.videoCB

    # setup controls in file info
    file.videoControls = $.el 'span',
      className: 'video-controls'
    if Conf['Show Controls']
      contract = $.el 'a',
        textContent: 'contract'
        href: 'javascript:;'
        title: 'You can also contract the video by dragging it to the left.'
      $.on contract, 'click', (e) -> ImageExpand.contract post
      $.add file.videoControls, [$.tn('\u00A0'), contract]
    $.add file.text, file.videoControls

  error: ->
    post = Get.postFromNode @
    $.rm @
    delete post.file.fullImage
    # Images can error:
    #  - before the image started loading.
    #  - after the image started loading.
    unless $.hasClass(post.file.thumb, 'expanding') or $.hasClass post.nodes.root, 'expanded-image'
      # Don't try to re-expand if it was already contracted.
      return
    ImageExpand.contract post
    ImageCommon.error @, post,
      ((URL) -> setTimeout ImageExpand.expand, 10 * $.SECOND, post, URL),
      (-> setTimeout ImageExpand.expand, 10 * $.SECOND, post)

  menu:
    init: ->
      return if g.VIEW is 'catalog' or !Conf['Image Expansion']

      el = $.el 'span',
        textContent: 'Image Expansion'
        className: 'image-expansion-link'

      {createSubEntry} = ImageExpand.menu
      subEntries = []
      for name, conf of Config.imageExpansion
        subEntries.push createSubEntry name, conf[1]

      Header.menu.addEntry
        el: el
        order: 105
        subEntries: subEntries

    createSubEntry: (name, desc) ->
      label = UI.checkbox name, " #{name}"
      label.title = desc
      input = label.firstElementChild
      if name in ['Fit width', 'Fit height']
        $.on input, 'change', ImageExpand.cb.setFitness
      $.event 'change', null, input
      $.on input, 'change', $.cb.checked
      el: label
