ThreadHiding =
  init: ->
    return if g.VIEW isnt 'index'
    @getHiddenThreads()
    @syncFromCatalog()
    @clean()
    Thread::callbacks.push
      name: 'Thread Hiding'
      cb:   @node

  node: ->
    if @ID in ThreadHiding.hiddenThreads.threads
      ThreadHiding.hide @
    $.prepend @posts[@].nodes.root, ThreadHiding.makeButton @, 'hide'

  getHiddenThreads: ->
    hiddenThreads = $.get "hiddenThreads.#{g.BOARD}"
    unless hiddenThreads
      hiddenThreads =
        threads: []
        lastChecked: Date.now()
      $.set "hiddenThreads.#{g.BOARD}", hiddenThreads
    ThreadHiding.hiddenThreads = hiddenThreads

  syncFromCatalog: ->
    # Sync hidden threads from the catalog into the index.
    hiddenThreadsOnCatalog = JSON.parse(localStorage.getItem "4chan-hide-t-#{g.BOARD}") or {}
    ThreadHiding.hiddenThreads.threads = Object.keys(hiddenThreadsOnCatalog).map Number
    $.set "hiddenThreads.#{g.BOARD}", ThreadHiding.hiddenThreads

  clean: ->
    {hiddenThreads} = ThreadHiding
    {lastChecked} = hiddenThreads
    hiddenThreads.lastChecked = now = Date.now()

    return if lastChecked > now - $.DAY

    unless hiddenThreads.threads.length
      $.set "hiddenThreads.#{g.BOARD}", hiddenThreads
      return

    $.ajax "//api.4chan.org/#{g.BOARD}/catalog.json", onload: ->
      threads = []
      for obj in JSON.parse @response
        for thread in obj.threads
          threads.push thread.no if thread.no in hiddenThreads.threads
      hiddenThreads.threads = threads
      $.set "hiddenThreads.#{g.BOARD}", hiddenThreads

  makeButton: (thread, type) ->
    a = $.el 'a',
      className: "#{type}-thread-button"
      innerHTML: "<span>[&nbsp;#{if type is 'hide' then '-' else '+'}&nbsp;]</span>"
      href:      'javascript:;'
    $.on a, 'click', -> ThreadHiding.toggle thread
    a

  toggle: (thread) ->
    # Get fresh hidden threads.
    hiddenThreads = ThreadHiding.getHiddenThreads()
    hiddenThreadsCatalog = JSON.parse(localStorage.getItem "4chan-hide-t-#{g.BOARD}") or {}
    if thread.isHidden
      ThreadHiding.show thread
      hiddenThreads.threads.splice hiddenThreads.threads.indexOf(thread.ID), 1
      delete hiddenThreadsCatalog[thread]
    else
      ThreadHiding.hide thread
      hiddenThreads.threads.push thread.ID
      hiddenThreadsCatalog[thread] = true
    $.set "hiddenThreads.#{g.BOARD}", hiddenThreads
    localStorage.setItem "4chan-hide-t-#{g.BOARD}", JSON.stringify hiddenThreadsCatalog

  hide: (thread, makeStub=Conf['Stubs']) ->
    return if thread.hidden
    op = thread.posts[thread]
    threadRoot = op.nodes.root.parentNode
    threadRoot.hidden = thread.isHidden = true

    unless makeStub
      threadRoot.nextElementSibling.hidden = true # <hr>
      return

    numReplies = 0
    if span = $ '.summary', threadRoot
      numReplies = +span.textContent.match /\d+/
    numReplies += $$('.opContainer ~ .replyContainer', threadRoot).length
    numReplies  = if numReplies is 1 then '1 reply' else "#{numReplies} replies"
    opInfo =
      if Conf['Anonymize']
        'Anonymous'
      else
        $('.nameBlock', op.nodes.info).textContent

    a = ThreadHiding.makeButton thread, 'show'
    $.add a, $.tn " #{opInfo} (#{numReplies})"
    thread.stub = $.el 'div',
      className: 'stub'
    $.add thread.stub, a
    # if Conf['Menu']
    #   $.add thread.stub, [$.tn(' '), Menu.makeButton()]
    $.before threadRoot, thread.stub

  show: (thread) ->
    if thread.stub
      $.rm thread.stub
      delete thread.stub
    threadRoot = thread.posts[thread].nodes.root.parentNode
    threadRoot.nextElementSibling.hidden =
      threadRoot.hidden = thread.isHidden = false

ReplyHiding =
  init: ->
    @getHiddenPosts()
    @clean()
    Post::callbacks.push
      name: 'Reply Hiding'
      cb:   @node

  node: ->
    return if !@isReply or @isClone
    if thread = ReplyHiding.hiddenPosts.threads[@thread]
      if @ID in thread
        ReplyHiding.hide @
    $.replace $('.sideArrows', @nodes.root), ReplyHiding.makeButton @, 'hide'

  getHiddenPosts: ->
    hiddenPosts = $.get "hiddenPosts.#{g.BOARD}"
    unless hiddenPosts
      hiddenPosts =
        threads: {}
        lastChecked: Date.now()
      $.set "hiddenPosts.#{g.BOARD}", hiddenPosts
    ReplyHiding.hiddenPosts = hiddenPosts

  clean: ->
    {hiddenPosts} = ReplyHiding
    {lastChecked} = hiddenPosts
    hiddenPosts.lastChecked = now = Date.now()

    return if lastChecked > now - $.DAY

    unless Object.keys(hiddenPosts.threads).length
      $.set "hiddenPosts.#{g.BOARD}", hiddenPosts
      return

    $.ajax "//api.4chan.org/#{g.BOARD}/catalog.json", onload: ->
      threads = {}
      for obj in JSON.parse @response
        for thread in obj.threads
          if thread.no of hiddenPosts.threads
            threads[thread.no] = hiddenPosts.threads[thread.no]
      hiddenPosts.threads = threads
      $.set "hiddenPosts.#{g.BOARD}", hiddenPosts

  makeButton: (post, type) ->
    a = $.el 'a',
      className: "#{type}-reply-button"
      innerHTML: "<span>[&nbsp;#{if type is 'hide' then '-' else '+'}&nbsp;]</span>"
      href:      'javascript:;'
    $.on a, 'click', -> ReplyHiding.toggle post
    a

  toggle: (post) ->
    # Get fresh hidden posts.
    hiddenPosts = ReplyHiding.getHiddenPosts()
    if post.isHidden
      ReplyHiding.show post
      thread = hiddenPosts.threads[post.thread]
      if (index = thread.indexOf post.ID) > -1
        # Was manually hidden, not by recursion/filtering.
        if thread.length is 1
          delete hiddenPosts.threads[post.thread]
        else
          thread.splice index, 1
    else
      ReplyHiding.hide post
      unless thread = hiddenPosts.threads[post.thread]
        thread = hiddenPosts.threads[post.thread] = []
      thread.push post.ID
    $.set "hiddenPosts.#{g.BOARD}", hiddenPosts

  hide: (post, makeStub=Conf['Stubs'], hideRecursively=Conf['Recursive Hiding']) ->
    return if post.isHidden
    post.isHidden = true

    Recursive.hide post, makeStub, true if hideRecursively

    for quotelink in Get.allQuotelinksLinkingTo post
      $.addClass quotelink, 'filtered'

    return unless makeStub
    a = ReplyHiding.makeButton post, 'show'
    postInfo =
      if Conf['Anonymize']
        'Anonymous'
      else
        $('.nameBlock', post.nodes.info).textContent
    $.add a, $.tn " #{postInfo}"
    post.nodes.stub = $.el 'div',
      className: 'stub'
    $.add post.nodes.stub, a
    # if Conf['Menu']
    #   $.add post.nodes.stub, [$.tn(' '), Menu.makeButton()]
    $.prepend post.nodes.root, post.nodes.stub

  show: (post) ->
    if post.nodes.stub
      $.rm post.nodes.stub
      delete post.nodes.stub
    post.isHidden = false
    for quotelink in Get.allQuotelinksLinkingTo post
      $.rmClass quotelink, 'filtered'
    return

Recursive =
  toHide: []
  init: ->
    Post::callbacks.push
      name: 'Recursive'
      cb:   @node

  node: ->
    return if @isClone
    # In fetched posts:
    #  - Strike-through quotelinks
    #  - Hide recursively
    for quote in @quotes
      if quote in Recursive.toHide
        ReplyHiding.hide @, !!g.posts[quote].nodes.stub, true
    for quotelink in @nodes.quotelinks
      {board, postID} = Get.postDataFromLink quotelink
      if g.posts["#{board}.#{postID}"]?.isHidden
        $.addClass quotelink, 'filtered'
    return

  hide: (post, makeStub) ->
    {fullID} = post
    Recursive.toHide.push fullID
    for ID, post of g.posts
      continue if !post.isReply or post.isHidden
      for quote in post.quotes
        if quote is fullID
          ReplyHiding.hide post, makeStub, true
          break
    return

Redirect =
  image: (board, filename) ->
    # XXX need to differentiate between thumbnail only and full_image for img src=
    # Do not use g.BOARD, the image url can originate from a cross-quote.
    switch board.ID
      when 'a', 'co', 'jp', 'm', 'q', 'sp', 'tg', 'tv', 'v', 'vg', 'wsg'
        "//archive.foolz.us/#{board}/full_image/#{filename}"
      when 'u'
        "//nsfw.foolz.us/#{board}/full_image/#{filename}"
      when 'po'
        "http://archive.thedarkcave.org/#{board}/full_image/#{filename}"
      when 'ck', 'lit'
        "//fuuka.warosu.org/#{board}/full_image/#{filename}"
      when 'diy', 'sci'
        "//archive.installgentoo.net/#{board}/full_image/#{filename}"
      when 'cgl', 'g', 'mu', 'w'
        "//rbt.asia/#{board}/full_image/#{filename}"
      when 'an', 'fit', 'k', 'mlp', 'r9k', 'toy', 'x'
        "http://archive.heinessen.com/#{board}/full_image/#{filename}"
      when 'c'
        "//archive.nyafuu.org/#{board}/full_image/#{filename}"
  post: (board, postID) ->
    switch board.ID
      when 'a', 'co', 'jp', 'm', 'q', 'sp', 'tg', 'tv', 'v', 'vg', 'wsg', 'dev', 'foolz'
        "//archive.foolz.us/_/api/chan/post/?board=#{board}&num=#{postID}"
      when 'u', 'kuku'
        "//nsfw.foolz.us/_/api/chan/post/?board=#{board}&num=#{postID}"
      when 'po'
        "http://archive.thedarkcave.org/_/api/chan/post/?board=#{board}&num=#{postID}"
    # for fuuka-based archives:
    # https://github.com/eksopl/fuuka/issues/27
  to: (data) ->
    {board} = data
    switch board.ID
      when 'a', 'co', 'jp', 'm', 'q', 'sp', 'tg', 'tv', 'v', 'vg', 'wsg', 'dev', 'foolz'
        url = Redirect.path '//archive.foolz.us', 'foolfuuka', data
      when 'u', 'kuku'
        url = Redirect.path '//nsfw.foolz.us', 'foolfuuka', data
      when 'po'
        url = Redirect.path 'http://archive.thedarkcave.org', 'foolfuuka', data
      when 'ck', 'lit'
        url = Redirect.path '//fuuka.warosu.org', 'fuuka', data
      when 'diy', 'sci'
        url = Redirect.path '//archive.installgentoo.net', 'fuuka', data
      when 'cgl', 'g', 'mu', 'w'
        url = Redirect.path '//rbt.asia', 'fuuka', data
      when 'an', 'fit', 'k', 'mlp', 'r9k', 'toy', 'x'
        url = Redirect.path 'http://archive.heinessen.com', 'fuuka', data
      when 'c'
        url = Redirect.path '//archive.nyafuu.org', 'fuuka', data
      else
        if data.threadID
          url = "//boards.4chan.org/#{board}/"
    url or ''
  path: (base, archiver, data) ->
    if data.isSearch
      {board, type, value} = data
      type =
        if type is 'name'
          'username'
        else if type is 'md5'
          'image'
        else
          type
      value = encodeURIComponent value
      return if archiver is 'foolfuuka'
          "#{base}/#{board}/search/#{type}/#{value}"
        else if type is 'image'
          "#{base}/#{board}/?task=search2&search_media_hash=#{value}"
        else
          "#{base}/#{board}/?task=search2&search_#{type}=#{value}"

    {board, threadID, postID} = data
    # keep the number only if the location.hash was sent f.e.
    postID = postID.match(/\d+/)[0] if postID
    path =
      if threadID
        "#{board}/thread/#{threadID}"
      else
        "#{board}/post/#{postID}"
    if archiver is 'foolfuuka'
      path += '/'
    if threadID and postID
      path +=
        if archiver is 'foolfuuka'
          "##{postID}"
        else
          "#p#{postID}"
    "#{base}/#{path}"

Build =
  spoilerRange: {}
  shortFilename: (filename, isReply) ->
    # FILENAME SHORTENING SCIENCE:
    # OPs have a +10 characters threshold.
    # The file extension is not taken into account.
    threshold = if isReply then 30 else 40
    if filename.length - 4 > threshold
      "#{filename[...threshold - 5]}(...).#{filename[-3..]}"
    else
      filename
  postFromObject: (data, board) ->
    o =
      # id
      postID:   data.no
      threadID: data.resto or data.no
      board:    board
      # info
      name:     data.name
      capcode:  data.capcode
      tripcode: data.trip
      uniqueID: data.id
      email:    if data.email then encodeURI data.email.replace /&quot;/g, '"' else ''
      subject:  data.sub
      flagCode: data.country
      flagName: data.country_name
      date:     data.now
      dateUTC:  data.time
      comment:  data.com
      # thread status
      isSticky: !!data.sticky
      isClosed: !!data.closed
      # file
    if data.ext or data.filedeleted
      o.file =
        name:      data.filename + data.ext
        timestamp: "#{data.tim}#{data.ext}"
        url:       "//images.4chan.org/#{board}/src/#{data.tim}#{data.ext}"
        height:    data.h
        width:     data.w
        MD5:       data.md5
        size:      data.fsize
        turl:      "//thumbs.4chan.org/#{board}/thumb/#{data.tim}s.jpg"
        theight:   data.tn_h
        twidth:    data.tn_w
        isSpoiler: !!data.spoiler
        isDeleted: !!data.filedeleted
    Build.post o
  post: (o, isArchived) ->
    ###
    This function contains code from 4chan-JS (https://github.com/4chan/4chan-JS).
    @license: https://github.com/4chan/4chan-JS/blob/master/LICENSE
    ###
    {
      postID, threadID, board
      name, capcode, tripcode, uniqueID, email, subject, flagCode, flagName, date, dateUTC
      isSticky, isClosed
      comment
      file
    } = o
    isOP = postID is threadID

    staticPath = '//static.4chan.org'

    if email
      emailStart = '<a href="mailto:' + email + '" class="useremail">'
      emailEnd   = '</a>'
    else
      emailStart = ''
      emailEnd   = ''

    subject =
      if subject
        "<span class=subject>#{subject}</span>"
      else
        ''

    userID =
      if !capcode and uniqueID
        " <span class='posteruid id_#{uniqueID}'>(ID: " +
          "<span class=hand title='Highlight posts by this ID'>#{uniqueID}</span>)</span> "
      else
        ''

    switch capcode
      when 'admin', 'admin_highlight'
        capcodeClass = " capcodeAdmin"
        capcodeStart = " <strong class='capcode hand id_admin'" +
          "title='Highlight posts by the Administrator'>## Admin</strong>"
        capcode      = " <img src='#{staticPath}/image/adminicon.gif' " +
          "alt='This user is the 4chan Administrator.' " +
          "title='This user is the 4chan Administrator.' class=identityIcon>"
      when 'mod'
        capcodeClass = " capcodeMod"
        capcodeStart = " <strong class='capcode hand id_mod' " +
          "title='Highlight posts by Moderators'>## Mod</strong>"
        capcode      = " <img src='#{staticPath}/image/modicon.gif' " +
          "alt='This user is a 4chan Moderator.' " +
          "title='This user is a 4chan Moderator.' class=identityIcon>"
      when 'developer'
        capcodeClass = " capcodeDeveloper"
        capcodeStart = " <strong class='capcode hand id_developer' " +
          "title='Highlight posts by Developers'>## Developer</strong>"
        capcode      = " <img src='#{staticPath}/image/developericon.gif' " +
          "alt='This user is a 4chan Developer.' " +
          "title='This user is a 4chan Developer.' class=identityIcon>"
      else
        capcodeClass = ''
        capcodeStart = ''
        capcode      = ''

    flag =
      if flagCode
       " <img src='#{staticPath}/image/country/#{if board is 'pol' then 'troll/' else ''}" +
        flagCode.toLowerCase() + ".gif' alt=#{flagCode} title='#{flagName}' class=countryFlag>"
      else
        ''

    if file?.isDeleted
      fileHTML =
        if isOP
          "<div id=f#{postID} class=file><div class=fileInfo></div><span class=fileThumb>" +
              "<img src='#{staticPath}/image/filedeleted.gif' alt='File deleted.' class='fileDeleted retina'>" +
          "</span></div>"
        else
          "<div id=f#{postID} class=file><span class=fileThumb>" +
            "<img src='#{staticPath}/image/filedeleted-res.gif' alt='File deleted.' class='fileDeletedRes retina'>" +
          "</span></div>"
    else if file
      ext = file.name[-3..]
      if !file.twidth and !file.theight and ext is 'gif' # wtf ?
        file.twidth  = file.width
        file.theight = file.height

      fileSize = $.bytesToString file.size

      fileThumb = file.turl
      if file.isSpoiler
        fileSize = "Spoiler Image, #{fileSize}"
        unless isArchived
          fileThumb = '//static.4chan.org/image/spoiler'
          if spoilerRange = Build.spoilerRange[board]
            # Randomize the spoiler image.
            fileThumb += "-#{board}" + Math.floor 1 + spoilerRange * Math.random()
          fileThumb += '.png'
          file.twidth = file.theight = 100

      imgSrc = "<a class='fileThumb#{if file.isSpoiler then ' imgspoiler' else ''}' href='#{file.url}' target=_blank>" +
        "<img src='#{fileThumb}' alt='#{fileSize}' data-md5=#{file.MD5} style='width:#{file.twidth}px;height:#{file.theight}px'></a>"

      # Ha Ha filenames.
      # html -> text, translate WebKit's %22s into "s
      a = $.el 'a', innerHTML: file.name
      filename = a.textContent.replace /%22/g, '"'

      # shorten filename, get html
      a.textContent = Build.shortFilename filename
      shortFilename = a.innerHTML

      # get html
      a.textContent = filename
      filename      = a.innerHTML.replace /'/g, '&apos;'

      fileDims = if ext is 'pdf' then 'PDF' else "#{file.width}x#{file.height}"
      fileInfo = "<span class=fileText id=fT#{postID}#{if file.isSpoiler then " title='#{filename}'" else ''}>File: <a href='#{file.url}' target=_blank>#{file.timestamp}</a>" +
        "-(#{fileSize}, #{fileDims}#{
          if file.isSpoiler
            ''
          else
            ", <span title='#{filename}'>#{shortFilename}</span>"
        }" + ")</span>"

      fileHTML = "<div id=f#{postID} class=file><div class=fileInfo>#{fileInfo}</div>#{imgSrc}</div>"
    else
      fileHTML = ''

    tripcode =
      if tripcode
        " <span class=postertrip>#{tripcode}</span>"
      else
        ''

    sticky =
      if isSticky
        ' <img src=//static.4chan.org/image/sticky.gif alt=Sticky title=Sticky style="height:16px;width:16px">'
      else
        ''
    closed =
      if isClosed
        ' <img src=//static.4chan.org/image/closed.gif alt=Closed title=Closed style="height:16px;width:16px">'
      else
        ''

    container = $.el 'div',
      id: "pc#{postID}"
      className: "postContainer #{if isOP then 'op' else 'reply'}Container"
      innerHTML: \
      (if isOP then '' else "<div class=sideArrows id=sa#{postID}>&gt;&gt;</div>") +
      "<div id=p#{postID} class='post #{if isOP then 'op' else 'reply'}#{
        if capcode is 'admin_highlight'
          ' highlightPost'
        else
          ''
        }'>" +

        "<div class='postInfoM mobile' id=pim#{postID}>" +
          "<span class='nameBlock#{capcodeClass}'>" +
              "<span class=name>#{name or ''}</span>" + tripcode +
            capcodeStart + capcode + userID + flag + sticky + closed +
            "<br>#{subject}" +
          "</span><span class='dateTime postNum' data-utc=#{dateUTC}>#{date}" +
          '<br><em>' +
            "<a href=#{"/#{board}/res/#{threadID}#p#{postID}"}>No.</a>" +
            "<a href='#{
              if g.VIEW is 'thread' and g.THREAD is threadID
                "javascript:quote(#{postID})"
              else
                "/#{board}/res/#{threadID}#q#{postID}"
              }'>#{postID}</a>" +
          '</em></span>' +
        '</div>' +

        (if isOP then fileHTML else '') +

        "<div class='postInfo desktop' id=pi#{postID}>" +
          "<input type=checkbox name=#{postID} value=delete> " +
          "#{subject} " +
          "<span class='nameBlock#{capcodeClass}'>" +
            emailStart +
              "<span class=name>#{name or ''}</span>" + tripcode +
            capcodeStart + emailEnd + capcode + userID + flag + sticky + closed +
          ' </span> ' +
          "<span class=dateTime data-utc=#{dateUTC}>#{date}</span> " +
          "<span class='postNum desktop'>" +
            "<a href=#{"/#{board}/res/#{threadID}#p#{postID}"} title='Highlight this post'>No.</a>" +
            "<a href='#{
              if g.VIEW is 'thread' and g.THREAD is threadID
                "javascript:quote(#{postID})"
              else
                "/#{board}/res/#{threadID}#q#{postID}"
              }' title='Quote this post'>#{postID}</a>" +
          '</span>' +
        '</div>' +

        (if isOP then '' else fileHTML) +

        "<blockquote class=postMessage id=m#{postID}>#{comment or ''}</blockquote> " +

      '</div>'

    for quote in $$ '.quotelink', container
      href = quote.getAttribute 'href'
      continue if href[0] is '/' # Cross-board quote, or board link
      quote.href = "/#{board}/res/#{href}" # Fix pathnames

    container

Get =
  postFromRoot: (root) ->
    link   = $ 'a[title="Highlight this post"]', root
    board  = link.pathname.split('/')[1]
    postID = link.hash[2..]
    index  = root.dataset.clone
    post   = g.posts["#{board}.#{postID}"]
    if index then post.clones[index] else post
  postDataFromLink: (link) ->
    if link.hostname is 'boards.4chan.org'
      path     = link.pathname.split '/'
      board    = path[1]
      threadID = path[3]
      postID   = link.hash[2..]
    else # resurrected quote
      board    = link.dataset.board
      threadID = link.dataset.threadid or 0
      postID   = link.dataset.postid
    return {
      board:    board
      threadID: +threadID
      postID:   +postID
    }
  allQuotelinksLinkingTo: (post) ->
    # Get quotelinks & backlinks linking to the given post.
    quotelinks = []
    # First:
    #   In every posts,
    #   if it did quote this post,
    #   get all their backlinks.
    for ID, quoterPost of g.posts
      if -1 isnt quoterPost.quotes.indexOf post.fullID
        for quoterPost in [quoterPost].concat quoterPost.clones
          quotelinks.push.apply quotelinks, quoterPost.nodes.quotelinks
    # Second:
    #   If we have quote backlinks:
    #   in all posts this post quoted
    #   and their clones,
    #   get all of their backlinks.
    if Conf['Quote Backlinks']
      for quote in post.quotes
        continue unless quotedPost = g.posts[quote]
        for quotedPost in [quotedPost].concat quotedPost.clones
          quotelinks.push.apply quotelinks, Array::slice.call quotedPost.nodes.backlinks
    # Third:
    #   Filter out irrelevant quotelinks.
    quotelinks.filter (quotelink) ->
      {board, postID} = Get.postDataFromLink quotelink
      board is post.board.ID and postID is post.ID
  contextFromLink: (quotelink) ->
    Get.postFromRoot $.x 'ancestor::div[parent::div[@class="thread"]][1]', quotelink
  postClone: (board, threadID, postID, root, context) ->
    if post = g.posts["#{board}.#{postID}"]
      Get.insert post, root, context
      return

    root.textContent = "Loading post No.#{postID}..."
    if threadID
      $.cache "//api.4chan.org/#{board}/res/#{threadID}.json", ->
        Get.fetchedPost @, board, threadID, postID, root, context
    else if url = Redirect.post board, postID
      $.cache url, ->
        Get.archivedPost @, board, postID, root, context
  insert: (post, root, context) ->
    # Stop here if the container has been removed while loading.
    return unless root.parentNode
    clone = post.addClone context
    Main.callbackNodes Post, [clone]

    # Get rid of the side arrows.
    {nodes} = clone
    nodes.root.innerHTML = null
    $.add nodes.root, nodes.post

    root.innerHTML = null
    $.add root, nodes.root
  fetchedPost: (req, board, threadID, postID, root, context) ->
    # In case of multiple callbacks for the same request,
    # don't parse the same original post more than once.
    if post = g.posts["#{board}.#{postID}"]
      Get.insert post, root, context
      return

    {status} = req
    if status isnt 200
      # The thread can die by the time we check a quote.
      if url = Redirect.post board, postID
        $.cache url, ->
          Get.archivedPost @, board, postID, root, context
      else
        $.addClass root, 'warning'
        root.textContent =
          if status is 404
            "Thread No.#{threadID} 404'd."
          else
            "Error #{req.status}: #{req.statusText}."
      return

    posts = JSON.parse(req.response).posts
    Build.spoilerRange[board] = posts[0].custom_spoiler
    for post in posts
      break if post.no is postID # we found it!
      if post.no > postID
        # The post can be deleted by the time we check a quote.
        if url = Redirect.post board, postID
          $.cache url, ->
            Get.archivedPost @, board, postID, root, context
        else
          $.addClass root, 'warning'
          root.textContent = "Post No.#{postID} was not found."
        return

    board = g.boards[board] or
      new Board board
    thread = g.threads["#{board}.#{threadID}"] or
      new Thread threadID, board
    post = new Post Build.postFromObject(post, board), thread, board
    Main.callbackNodes Post, [post]
    Get.insert post, root, context
  archivedPost: (req, board, postID, root, context) ->
    # In case of multiple callbacks for the same request,
    # don't parse the same original post more than once.
    if post = g.posts["#{board}.#{postID}"]
      Get.insert post, root, context
      return

    data = JSON.parse req.response
    if data.error
      $.addClass root, 'warning'
      root.textContent = data.error
      return

    # convert comment to html
    bq = $.el 'blockquote', textContent: data.comment # set this first to convert text to HTML entities
    # https://github.com/eksopl/fuuka/blob/master/Board/Yotsuba.pm#L413-452
    # https://github.com/eksopl/asagi/blob/master/src/main/java/net/easymodo/asagi/Yotsuba.java#L109-138
    bq.innerHTML = bq.innerHTML.replace ///
      \n
      | \[/?b\]
      | \[/?spoiler\]
      | \[/?code\]
      | \[/?moot\]
      | \[/?banned\]
      ///g, (text) ->
        switch text
          when '\n'
            '<br>'
          when '[b]'
            '<b>'
          when '[/b]'
            '</b>'
          when '[spoiler]'
            '<span class=spoiler>'
          when '[/spoiler]'
            '</span>'
          when '[code]'
            '<pre class=prettyprint>'
          when '[/code]'
            '</pre>'
          when '[moot]'
            '<div style="padding:5px;margin-left:.5em;border-color:#faa;border:2px dashed rgba(255,0,0,.1);border-radius:2px">'
          when '[/moot]'
            '</div>'
          when '[banned]'
            '<b style="color: red;">'
          when '[/banned]'
            '</b>'

    comment = bq.innerHTML
      # greentext
      .replace(/(^|>)(&gt;[^<$]*)(<|$)/g, '$1<span class=quote>$2</span>$3')
      # quotes
      .replace /((&gt;){2}(&gt;\/[a-z\d]+\/)?\d+)/g, '<span class=deadlink>$1</span>'

    threadID = data.thread_num
    o =
      # id
      postID:   "#{postID}"
      threadID: "#{threadID}"
      board:    board
      # info
      name:     data.name_processed
      capcode:  switch data.capcode
        when 'M' then 'mod'
        when 'A' then 'admin'
        when 'D' then 'developer'
      tripcode: data.trip
      uniqueID: data.poster_hash
      email:    if data.email then encodeURI data.email else ''
      subject:  data.title_processed
      flagCode: data.poster_country
      flagName: data.poster_country_name_processed
      date:     data.fourchan_date
      dateUTC:  data.timestamp
      comment:  comment
      # file
    if data.media?.media_filename
      o.file =
        name:      data.media.media_filename_processed
        timestamp: data.media.media_orig
        url:       data.media.media_link or data.media.remote_media_link
        height:    data.media.media_h
        width:     data.media.media_w
        MD5:       data.media.media_hash
        size:      data.media.media_size
        turl:      data.media.thumb_link or "//thumbs.4chan.org/#{board}/thumb/#{data.media.preview_orig}"
        theight:   data.media.preview_h
        twidth:    data.media.preview_w
        isSpoiler: data.media.spoiler is '1'

    board = g.boards[board] or
      new Board board
    thread = g.threads["#{board}.#{threadID}"] or
      new Thread threadID, board
    post = new Post Build.post(o, true), thread, board,
      isArchived: true
    Main.callbackNodes Post, [post]
    Get.insert post, root, context

Quotify =
  init: ->
    Post::callbacks.push
      name: 'Resurrect Quotes'
      cb:   @node
  node: ->
    return if @isClone
    for deadlink in $$ '.deadlink', @nodes.comment
      if deadlink.parentNode.className is 'prettyprint'
        # Don't quotify deadlinks inside code tags,
        # un-`span` them.
        $.replace deadlink, Array::slice.call deadlink.childNodes
        continue

      quote = deadlink.textContent
      continue unless ID = quote.match(/\d+$/)?[0]
      board =
        if m = quote.match /^>>>\/([a-z\d]+)/
          m[1]
        else
          @board.ID
      quoteID = "#{board}.#{ID}"

      # \u00A0 is nbsp
      if post = g.posts[quoteID]
        unless post.isDead
          # Don't (Dead) when quotifying in an archived post,
          # and we know the post still exists.
          a = $.el 'a',
            href:        "/#{board}/#{post.thread}/res/#p#{ID}"
            className:   'quotelink'
            textContent: quote
        else if redirect = Redirect.to {board: board, threadID: post.thread.ID, postID: ID}
          # Replace the .deadlink span if we can redirect.
          a = $.el 'a',
            href:        redirect
            className:   'quotelink deadlink'
            target:      '_blank'
            textContent: "#{quote}\u00A0(Dead)"
          a.setAttribute 'data-board',    board
          a.setAttribute 'data-threadid', post.thread.ID
          a.setAttribute 'data-postid',   ID
      else if redirect = Redirect.to {board: board, threadID: 0, postID: ID}
        # Replace the .deadlink span if we can redirect.
        a = $.el 'a',
          href:        redirect
          className:   'deadlink'
          target:      '_blank'
          textContent: "#{quote}\u00A0(Dead)"
        if Redirect.post board, ID
          # Make it function as a normal quote if we can fetch the post.
          $.addClass a,  'quotelink'
          a.setAttribute 'data-board',  board
          a.setAttribute 'data-postid', ID

      if a
        $.replace deadlink, a
      else
        deadlink.textContent += "\u00A0(Dead)"

      if @quotes.indexOf(quoteID) is -1
        @quotes.push quoteID
      if $.hasClass a, 'quotelink'
        @nodes.quotelinks.push a
    return

QuoteInline =
  init: ->
    Post::callbacks.push
      name: 'Quote Inline'
      cb:   @node
  node: ->
    for link in @nodes.quotelinks
      $.on link, 'click', QuoteInline.toggle
    for link in @nodes.backlinks
      $.on link, 'click', QuoteInline.toggle
    return
  toggle: (e) ->
    return if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey or e.button isnt 0
    e.preventDefault()
    {board, threadID, postID} = Get.postDataFromLink @
    context = Get.contextFromLink @
    if $.hasClass @, 'inlined'
      QuoteInline.rm @, board, threadID, postID, context
    else
      return if $.x "ancestor::div[@id='p#{postID}']", @
      QuoteInline.add @, board, threadID, postID, context
    @classList.toggle 'inlined'

  findRoot: (quotelink, isBacklink) ->
    if isBacklink
      quotelink.parentNode.parentNode
    else
      $.x 'ancestor-or-self::*[parent::blockquote][1]', quotelink
  add: (quotelink, board, threadID, postID, context) ->
    isBacklink = $.hasClass quotelink, 'backlink'
    inline = $.el 'div',
      id: "i#{postID}"
      className: 'inline'
    $.after QuoteInline.findRoot(quotelink, isBacklink), inline
    Get.postClone board, threadID, postID, inline, context

    return unless (post = g.posts["#{board}.#{postID}"]) and
      context.thread is post.thread

    # Hide forward post if it's a backlink of a post in this thread.
    # Will only unhide if there's no inlined backlinks of it anymore.
    if isBacklink and Conf['Forward Hiding']
      $.addClass post.nodes.root, 'forwarded'
      post.forwarded++ or post.forwarded = 1

    # Decrease the unread count if this post is in the array of unread reply.
    # XXX
    # if (i = Unread.replies.indexOf el) isnt -1
    #   Unread.replies.splice i, 1
    #   Unread.update true

  rm: (quotelink, board, threadID, postID, context) ->
    isBacklink = $.hasClass quotelink, 'backlink'
    # Select the corresponding inlined quote, and remove it.
    root = QuoteInline.findRoot quotelink, isBacklink
    root = $.x "following-sibling::div[@id='i#{postID}'][1]", root
    $.rm root

    # Stop if it only contains text.
    return unless el = root.firstElementChild

    # Dereference clone.
    post = g.posts["#{board}.#{postID}"]
    post.rmClone el.dataset.clone

    # Decrease forward count and unhide.
    if Conf['Forward Hiding'] and
      isBacklink and
      context.thread is g.threads["#{board}.#{threadID}"] and
      not --post.forwarded
        delete post.forwarded
        $.rmClass post.nodes.root, 'forwarded'

    # Repeat.
    while inlined = $ '.inlined', el
      {board, threadID, postID} = Get.postDataFromLink inlined
      QuoteInline.rm inlined, board, threadID, postID, context
      $.rmClass inlined, 'inlined'
    return

QuotePreview =
  init: ->
    Post::callbacks.push
      name: 'Quote Preview'
      cb:   @node
  node: ->
    for link in @nodes.quotelinks
      $.on link, 'mouseover', QuotePreview.mouseover
    for link in @nodes.backlinks
      $.on link, 'mouseover', QuotePreview.mouseover
    return
  mouseover: (e) ->
    return if $.hasClass @, 'inlined'

    {board, threadID, postID} = Get.postDataFromLink @

    qp = $.el 'div',
      id: 'qp'
      className: 'reply dialog'
    $.add d.body, qp
    Get.postClone board, threadID, postID, qp, Get.contextFromLink @

    UI.hover @, qp, 'mouseout click', QuotePreview.mouseout

    return unless origin = g.posts["#{board}.#{postID}"]

    if Conf['Quote Highlighting']
      posts = [origin].concat origin.clones
      # Remove the clone that's in the qp from the array.
      posts.pop()
      for post in posts
        $.addClass post.nodes.post, 'qphl'

    quoterID = $.x('ancestor::*[@id][1]', @).id.match(/\d+$/)[0]
    clone = Get.postFromRoot qp.firstChild
    for quote in clone.nodes.quotelinks
      if quote.hash[2..] is quoterID
        $.addClass quote, 'forwardlink'
    for quote in clone.nodes.backlinks
      if quote.hash[2..] is quoterID
        $.addClass quote, 'forwardlink'
    return
  mouseout: ->
    # Stop if it only contains text.
    return unless root = @el.firstElementChild

    clone = Get.postFromRoot root
    post  = clone.origin
    post.rmClone root.dataset.clone

    return unless Conf['Quote Highlighting']
    for post in [post].concat post.clones
      $.rmClass post.nodes.post, 'qphl'
    return

QuoteBacklink =
  # Backlinks appending need to work for:
  #  - previous, same, and following posts.
  #  - existing and yet-to-exist posts.
  #  - newly fetched posts.
  #  - in copies.
  # XXX what about order for fetched posts?
  #
  # First callback creates backlinks and add them to relevant containers.
  # Second callback adds relevant containers into posts.
  # This is is so that fetched posts can get their backlinks,
  # and that as much backlinks are appended in the background as possible.
  init: ->
    format = Conf['backlink'].replace /%id/g, "' + id + '"
    @funk  = Function 'id', "return '#{format}'"
    @containers = {}
    Post::callbacks.push
      name: 'Quote Backlinking Part 1'
      cb:   @firstNode
    Post::callbacks.push
      name: 'Quote Backlinking Part 2'
      cb:   @secondNode
  firstNode: ->
    return if @isClone or !@quotes.length
    a = $.el 'a',
      href: "/#{@board}/res/#{@thread}#p#{@}"
      className: if @isHidden then 'filtered backlink' else 'backlink'
      textContent: QuoteBacklink.funk @ID
    for quote in @quotes
      containers = [QuoteBacklink.getContainer quote]
      if post = g.posts[quote]
        for clone in post.clones
          containers.push clone.nodes.backlinkContainer
      for container in containers
        link = a.cloneNode true
        if Conf['Quote Preview']
          $.on link, 'mouseover', QuotePreview.mouseover
        if Conf['Quote Inline']
          $.on link, 'click', QuoteInline.toggle
        $.add container, [$.tn(' '), link]
    return
  secondNode: ->
    if @isClone and @origin.nodes.backlinkContainer
      @nodes.backlinkContainer = $ '.container', @nodes.info
      return
    # Don't backlink the OP.
    return unless Conf['OP Backlinks'] or @isReply
    container = QuoteBacklink.getContainer @fullID
    @nodes.backlinkContainer = container
    $.add @nodes.info, container
  getContainer: (id) ->
    @containers[id] or=
      $.el 'span', className: 'container'

QuoteOP =
  init: ->
    # \u00A0 is nbsp
    @text = '\u00A0(OP)'
    Post::callbacks.push
      name: 'Indicate OP Quotes'
      cb:   @node
  node: ->
    # Stop there if it's a clone of a post in the same thread.
    return if @isClone and @thread is @context.thread
    # Stop there if there's no quotes in that post.
    return unless (quotes = @quotes).length
    quotelinks = @nodes.quotelinks

    # rm (OP) from cross-thread quotes.
    if @isClone and -1 < quotes.indexOf @fullID
      for quote in quotelinks
        quote.textContent = quote.textContent.replace QuoteOP.text, ''

    op = (if @isClone then @context else @).thread.fullID
    # add (OP) to quotes quoting this context's OP.
    return unless -1 < quotes.indexOf op
    for quote in quotelinks
      {board, postID} = Get.postDataFromLink quote
      if "#{board}.#{postID}" is op
        $.add quote, $.tn QuoteOP.text
    return

QuoteCT =
  init: ->
    # \u00A0 is nbsp
    @text = '\u00A0(Cross-thread)'
    Post::callbacks.push
      name: 'Indicate Cross-thread Quotes'
      cb:   @node
  node: ->
    # Stop there if it's a clone of a post in the same thread.
    return if @isClone and @thread is @context.thread
    # Stop there if there's no quotes in that post.
    return unless (quotes = @quotes).length
    quotelinks = @nodes.quotelinks

    {board, thread} = if @isClone then @context else @
    for quote in quotelinks
      data = Get.postDataFromLink quote
      continue unless data.threadID # deadlink
      if @isClone
        quote.textContent = quote.textContent.replace QuoteCT.text, ''
      if data.board is @board.ID and data.threadID isnt thread.ID
        $.add quote, $.tn QuoteCT.text
    return

Anonymize =
  init: ->
    Post::callbacks.push
      name: 'Anonymize'
      cb:   @node
  node: ->
    return if @info.capcode or @isClone
    {name, tripcode, email} = @nodes
    if @info.name isnt 'Anonymous'
      name.textContent = 'Anonymous'
    if tripcode
      $.rm tripcode
      delete @nodes.tripcode
    if @info.email
      if /sage/i.test @info.email
        email.href = 'mailto:sage'
      else
        $.replace email, name
        delete @nodes.email

Time =
  init: ->
    @funk = @createFunc Conf['time']
    Post::callbacks.push
      name: 'Time Formatting'
      cb:   @node
  node: ->
    return if @isClone
    @nodes.date.textContent = Time.funk Time, @info.date
  createFunc: (format) ->
    code = format.replace /%([A-Za-z])/g, (s, c) ->
      if c of Time.formatters
        "' + Time.formatters.#{c}.call(date) + '"
      else
        s
    Function 'Time', 'date', "return '#{code}'"
  day: [
    'Sunday'
    'Monday'
    'Tuesday'
    'Wednesday'
    'Thursday'
    'Friday'
    'Saturday'
  ]
  month: [
    'January'
    'February'
    'March'
    'April'
    'May'
    'June'
    'July'
    'August'
    'September'
    'October'
    'November'
    'December'
  ]
  zeroPad: (n) -> if n < 10 then "0#{n}" else n
  formatters:
    a: -> Time.day[@getDay()][...3]
    A: -> Time.day[@getDay()]
    b: -> Time.month[@getMonth()][...3]
    B: -> Time.month[@getMonth()]
    d: -> Time.zeroPad @getDate()
    e: -> @getDate()
    H: -> Time.zeroPad @getHours()
    I: -> Time.zeroPad @getHours() % 12 or 12
    k: -> @getHours()
    l: -> @getHours() % 12 or 12
    m: -> Time.zeroPad @getMonth() + 1
    M: -> Time.zeroPad @getMinutes()
    p: -> if @getHours() < 12 then 'AM' else 'PM'
    P: -> if @getHours() < 12 then 'am' else 'pm'
    S: -> Time.zeroPad @getSeconds()
    y: -> @getFullYear() - 2000

FileInfo =
  init: ->
    @funk = @createFunc Conf['fileInfo']
    Post::callbacks.push
      name: 'File Info Formatting'
      cb:   @node
  node: ->
    return if !@file or @isClone
    @file.text.innerHTML = FileInfo.funk FileInfo, @
  createFunc: (format) ->
    code = format.replace /%(.)/g, (s, c) ->
      if c of FileInfo.formatters
        "' + FileInfo.formatters.#{c}.call(post) + '"
      else
        s
    Function 'FileInfo', 'post', "return '#{code}'"
  convertUnit: (size, unit) ->
    if unit is 'B'
      return "#{size.toFixed()} Bytes"
    i = 1 + ['KB', 'MB'].indexOf unit
    size /= 1024 while i--
    size =
      if unit is 'MB'
        Math.round(size * 100) / 100
      else
        size.toFixed()
    "#{size} #{unit}"
  escape: (name) ->
    name.replace /<|>/g, (c) ->
      c is '<' and '&lt;' or '&gt;'
  formatters:
    t: -> @file.URL.match(/\d+\..+$/)[0]
    T: -> "<a href=#{FileInfo.data.link} target=_blank>#{FileInfo.formatters.t.call @}</a>"
    l: -> "<a href=#{@file.URL} target=_blank>#{FileInfo.formatters.n.call @}</a>"
    L: -> "<a href=#{@file.URL} target=_blank>#{FileInfo.formatters.N.call @}</a>"
    n: ->
      fullname  = @file.name
      shortname = Build.shortFilename @file.name, @isReply
      if fullname is shortname
        FileInfo.escape fullname
      else
        "<span class=fntrunc>#{FileInfo.escape shortname}</span><span class=fnfull>#{FileInfo.escape fullname}</span>"
    N: -> FileInfo.escape @file.name
    p: -> if @file.isSpoiler then 'Spoiler, ' else ''
    s: -> $.bytesToString @file.size
    B: -> FileInfo.convertUnit @file.size, 'B'
    K: -> FileInfo.convertUnit @file.size, 'KB'
    M: -> FileInfo.convertUnit @file.size, 'MB'
    r: -> if @file.isImage then @file.dimensions else 'PDF'

Sauce =
  init: ->
    links = []
    for link in Conf['sauces'].split '\n'
      continue if link[0] is '#'
      # XXX .trim() is there to fix Opera reading two different line breaks.
      links.push @createSauceLink link.trim()
    return unless links.length
    @links = links
    @link  = $.el 'a', target: '_blank'
    Post::callbacks.push
      name: 'Sauce'
      cb:   @node
  createSauceLink: (link) ->
    link = link.replace /%(t?url|md5|board)/g, (parameter) ->
      switch parameter
        when '%turl'
          "' + post.file.thumbURL + '"
        when '%url'
          "' + post.file.URL + '"
        when '%md5'
          "' + encodeURIComponent(post.file.MD5) + '"
        when '%board'
          "' + post.board + '"
        else
          parameter
    text = if m = link.match(/;text:(.+)$/) then m[1] else link.match(/(\w+)\.\w+\//)[1]
    link = link.replace /;text:.+$/, ''
    Function 'post', 'a', """
      a.href = '#{link}';
      a.textContent = '#{text}';
      return a;
    """
  node: ->
    return if @isClone or !@file
    nodes = []
    for link in Sauce.links
      # \u00A0 is nbsp
      nodes.push $.tn('\u00A0'), link @, Sauce.link.cloneNode true
    $.add @file.info, nodes

RevealSpoilers =
  init: ->
    Post::callbacks.push
      name: 'Reveal Spoilers'
      cb:   @node
  node: ->
    return if @isClone or !@file?.isSpoiler
    {thumb} = @file
    thumb.removeAttribute 'style'
    thumb.src = @file.thumbURL

AutoGIF =
  init: ->
    return if g.BOARD.ID in ['gif', 'wsg']
    Post::callbacks.push
      name: 'Auto-GIF'
      cb:   @node
  node: ->
    return if @isClone or @isHidden or @thread.isHidden or !@file?.isImage
    {thumb, URL} = @file
    return unless /gif$/.test(URL) and !/spoiler/.test thumb.src
    if @file.isSpoiler
      # Revealed spoilers do not have height/width set, this fixes auto-gifs dimensions.
      {style} = thumb
      style.maxHeight = style.maxWidth = if @isReply then '125px' else '250px'
    gif = $.el 'img'
    $.on gif, 'load', ->
      # Replace the thumbnail once the GIF has finished loading.
      thumb.src = URL
    gif.src = URL

ImageHover =
  init: ->
    return if g.BOARD.ID in ['gif', 'wsg']
    Post::callbacks.push
      name: 'Auto-GIF'
      cb:   @node
  node: ->
    return unless @file?.isImage
    $.on @file.thumb, 'mouseover', ImageHover.mouseover
  mouseover: ->
    el = $.el 'img'
      id: 'ihover'
      src: @parentNode.href
    $.add d.body, el
    $.on el, 'load', => ImageHover.load @, el
    $.on el, 'error', ImageHover.error
    UI.hover @, el, 'mouseout'
  load: (root, el) ->
    return unless el.parentNode
    # 'Fake' mousemove event by giving required values.
    {style} = el
    e = new Event 'mousemove'
    e.clientX = - 45 + parseInt style.left
    e.clientY =  120 + parseInt style.top
    root.dispatchEvent e
  error: ->
    return unless @parentNode
    src = @src.split '/'
    unless src[2] is 'images.4chan.org' and url = Redirect.image src[3], src[5]
      return if g.DEAD
      url = "//images.4chan.org/#{src[3]}/src/#{src[5]}"
    return if $.engine isnt 'webkit' and url.split('/')[2] is 'images.4chan.org'
    timeoutID = setTimeout (=> @src = url), 3000
    # Only Chrome let userscripts do cross domain requests.
    # Don't check for 404'd status in the archivers.
    return if $.engine isnt 'webkit' or url.split('/')[2] isnt 'images.4chan.org'
    $.ajax url, onreadystatechange: (-> clearTimeout timeoutID if @status is 404),
      type: 'head'

ThreadUpdater =
  init: ->
    return if g.VIEW isnt 'thread'
    Thread::callbacks.push
      name: 'Thread Updater'
      cb:   @node
  node: ->
    new ThreadUpdater.Updater @
  ###
  http://freesound.org/people/pierrecartoons1979/sounds/90112/
  cc-by-nc-3.0
  ###
  beep: 'data:audio/wav;base64,UklGRjQDAABXQVZFZm10IBAAAAABAAEAgD4AAIA+AAABAAgAc21wbDwAAABBAAADAAAAAAAAAAA8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkYXRhzAIAAGMms8em0tleMV4zIpLVo8nhfSlcPR102Ki+5JspVEkdVtKzs+K1NEhUIT7DwKrcy0g6WygsrM2k1NpiLl0zIY/WpMrjgCdbPhxw2Kq+5Z4qUkkdU9K1s+K5NkVTITzBwqnczko3WikrqM+l1NxlLF0zIIvXpsnjgydZPhxs2ay95aIrUEkdUdC3suK8N0NUIjq+xKrcz002WioppdGm091pK1w0IIjYp8jkhydXPxxq2K295aUrTkoeTs65suK+OUFUIzi7xqrb0VA0WSoootKm0t5tKlo1H4TYqMfkiydWQBxm16+85actTEseS8y7seHAPD9TIza5yKra01QyWSson9On0d5wKVk2H4DYqcfkjidUQB1j1rG75KsvSkseScu8seDCPz1TJDW2yara1FYxWSwnm9Sn0N9zKVg2H33ZqsXkkihSQR1g1bK65K0wSEsfR8i+seDEQTxUJTOzy6rY1VowWC0mmNWoz993KVc3H3rYq8TklSlRQh1d1LS647AyR0wgRMbAsN/GRDpTJTKwzKrX1l4vVy4lldWpzt97KVY4IXbUr8LZljVPRCxhw7W3z6ZISkw1VK+4sMWvXEhSPk6buay9sm5JVkZNiLWqtrJ+TldNTnquqbCwilZXU1BwpKirrpNgWFhTaZmnpquZbFlbVmWOpaOonHZcXlljhaGhpZ1+YWBdYn2cn6GdhmdhYGN3lp2enIttY2Jjco+bnJuOdGZlZXCImJqakHpoZ2Zug5WYmZJ/bGlobX6RlpeSg3BqaW16jZSVkoZ0bGtteImSk5KIeG5tbnaFkJKRinxxbm91gY2QkIt/c3BwdH6Kj4+LgnZxcXR8iI2OjIR5c3J0e4WLjYuFe3VzdHmCioyLhn52dHR5gIiKioeAeHV1eH+GiYqHgXp2dnh9hIiJh4J8eHd4fIKHiIeDfXl4eHyBhoeHhH96eHmA'


  Updater: class
    constructor: (@thread) ->
      html = '<div class=move><span id=status></span> <span id=timer></span></div>'
      for name, val of Config.updater.checkbox
        title   = val[1]
        checked = if Conf[name] then 'checked' else ''
        html    += "<div><label title='#{title}'>#{name}<input name='#{name}' type=checkbox #{checked}></label></div>"

      checked = if Conf['Auto Update'] then 'checked' else ''
      html += """
        <div><label title='Controls whether *this* thread automatically updates or not'>Auto Update This<input name='Auto Update This' type=checkbox #{checked}></label></div>
        <div><label>Interval (s)<input type=number name=Interval class=field min=5 value=#{Conf['Interval']}></label></div>
        <div><input value='Update Now' type=button name='Update Now'></div>
        """

      dialog = UI.dialog 'updater', 'bottom: 0; right: 0;', html

      @timer  = $ '#timer',  dialog
      @status = $ '#status', dialog

      @unsuccessfulFetchCount = 0
      @lastModified = '0'
      @threadRoot = thread.posts[thread].nodes.root.parentNode
      @lastPost = +@threadRoot.lastElementChild.id[2..]

      for input in $$ 'input', dialog
        if input.type is 'checkbox'
          $.on input, 'click', @cb.checkbox.bind @
          input.dispatchEvent new Event 'click'
        switch input.name
          when 'Scroll BG'
            $.on input, 'click', @cb.scrollBG.bind @
            @cb.scrollBG.call @
          when 'Auto Update This'
            $.on input, 'click', @cb.autoUpdate.bind @
          when 'Interval'
            $.on input, 'change', @cb.interval.bind @
            input.dispatchEvent new Event 'change'
          when 'Update Now'
            $.on input, 'click', @update.bind @

      $.on window, 'online offline', @cb.online.bind @
      $.on d, 'QRPostSuccessful', @cb.post.bind @
      $.on d, 'visibilitychange ovisibilitychange mozvisibilitychange webkitvisibilitychange', @cb.visibility.bind @

      @cb.online.call @
      $.add d.body, dialog

    cb:
      online: ->
        if @online = navigator.onLine
          @unsuccessfulFetchCount = 0
          @set 'timer', @getInterval()
          @update() if Conf['Auto Update This']
          @set 'status', null
          @status.className = null
        else
          @status.className = 'warning'
          @set 'status', 'Offline'
          @set 'timer',  null
        @cb.autoUpdate.call @
      post: (e) ->
        return unless @['Auto Update This'] and +e.detail.threadID is @thread.ID
        @unsuccessfulFetchCount = 0
        setTimeout @update.bind(@), 1000 if @seconds > 2
      visibility: ->
        return if $.hidden()
        # Reset the counter when we focus this tab.
        @unsuccessfulFetchCount = 0
        if @seconds > @interval
          @set 'timer', @getInterval()
      checkbox: (e) ->
        input = e.target
        {checked, name} = input
        @[name] = checked
        $.cb.checked.call input
      scrollBG: ->
        @scrollBG =
          if @['Scroll BG']
            -> true
          else
            -> not $.hidden()
      autoUpdate: ->
        if @['Auto Update This'] and @online
          @timeoutID = setTimeout @timeout.bind(@), 1000
        else
          clearTimeout @timeoutID
      interval: (e) ->
        input = e.target
        val = Math.max 5, parseInt input.value, 10
        @interval = input.value = val
        $.cb.value.call input
      load: ->
        switch @req.status
          when 404
            @set 'timer', null
            @set 'status', '404'
            @status.className = 'warning'
            clearTimeout @timeoutID
            @thread.isDead = true
            # if Conf['Unread Count']
            #   Unread.title = Unread.title.match(/^.+-/)[0] + ' 404'
            # else
            #   d.title = d.title.match(/^.+-/)[0] + ' 404'
            # Unread.update true
            # QR.abort()
          # XXX 304 -> 0 in Opera
          when 0, 304
            ###
            Status Code 304: Not modified
            By sending the `If-Modified-Since` header we get a proper status code, and no response.
            This saves bandwidth for both the user and the servers and avoid unnecessary computation.
            ###
            @unsuccessfulFetchCount++
            @set 'timer', @getInterval()
            @set 'status', null
            @status.className = null
          when 200
            @parse JSON.parse(@req.response).posts
            @lastModified = @req.getResponseHeader 'Last-Modified'
            @set 'timer', @getInterval()
          else
            @unsuccessfulFetchCount++
            @set 'timer',  @getInterval()
            @set 'status', "#{@req.statusText} (#{@req.status})"
            @status.className = 'warning'
        delete @req

    getInterval: ->
      i = @interval
      j = Math.min @unsuccessfulFetchCount, 10
      unless $.hidden()
        # Lower the max refresh rate limit on visible tabs.
        j = Math.min j, 7
      @seconds = Math.max i, [0, 5, 10, 15, 20, 30, 60, 90, 120, 240, 300][j]

    set: (name, text) ->
      el = @[name]
      if node = el.firstChild
        # Prevent the creation of a new DOM Node
        # by setting the text node's data.
        node.data = text
      else
        el.textContent = text

    timeout: ->
      @timeoutID = setTimeout @timeout.bind(@), 1000
      unless n = --@seconds
        @update()
      else if n <= -60
        @set 'status', 'Retrying'
        @status.className = null
        @update()
      else if n > 0
        @set 'timer', n

    update: ->
      return unless @online
      @seconds = 0
      @set 'timer', '...'
      if @req
        # abort() triggers onloadend, we don't want that.
        @req.onloadend = null
        @req.abort()
      url = "//api.4chan.org/#{@thread.board}/res/#{@thread}.json"
      @req = $.ajax url, onloadend: @cb.load.bind @,
        headers: 'If-Modified-Since': @lastModified

    parse: (postObjects) ->
      Build.spoilerRange[@thread.board] = postObjects[0].custom_spoiler

      nodes = [] # post container elements
      posts = [] # post objects
      index = [] # existing posts
      image = [] # existing images
      count = 0  # new posts count
      # Build the index, create posts.
      for postObject in postObjects
        num = postObject.no
        index.push num
        image.push num if postObject.ext
        continue if num <= @lastPost
        # Insert new posts, not older ones.
        count++
        node = Build.postFromObject postObject, @thread.board.ID
        nodes.push node
        posts.push new Post node, @thread, @thread.board

      # Check for deleted posts and deleted images.
      for i, post of @thread.posts
        continue if post.isDead
        {ID} = post
        if -1 is index.indexOf ID
          post.kill()
        else if post.file and !post.file.isDead and -1 is image.indexOf ID
          post.kill true

      if count
        if Conf['Beep'] and $.hidden() and (Unread.replies.length is 0)
          unless @audio
            @audio = $.el 'audio', src: ThreadUpdater.beep
          audio.play()
        @set 'status', "+#{count}"
        @status.className = 'new'
        @unsuccessfulFetchCount = 0
      else
        @set 'status', null
        @status.className = null
        @unsuccessfulFetchCount++
        return

      @lastPost = posts[count - 1].ID
      Main.callbackNodes Post, posts

      scroll = @['Auto Scroll'] and @scrollBG() and
        @threadRoot.getBoundingClientRect().bottom - d.documentElement.clientHeight < 25
      $.add @threadRoot, nodes
      if scroll
        nodes[0].scrollIntoView()
