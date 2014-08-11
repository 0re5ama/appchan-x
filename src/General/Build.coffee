Build =
  initPixelRatio: window.devicePixelRatio
  spoilerRange: {}
  unescape: (text) ->
    return text unless text?
    text.replace /&(amp|#039|quot|lt|gt);/g, (c) ->
      {'&amp;': '&', '&#039;': "'", '&quot;': '"', '&lt;': '<', '&gt;': '>'}[c]
  shortFilename: (filename, isReply) ->
    threshold = 30
    ext = filename.match(/\.?[^\.]*$/)[0]
    if filename.length - ext.length > threshold
      "#{filename[...threshold - 5]}(...)#{ext}"
    else
      filename
  thumbRotate: do ->
    n = 0
    -> n = (n + 1) % 3
  sameThread: (boardID, threadID) ->
    g.VIEW is 'thread' and g.BOARD.ID is boardID and g.THREADID is +threadID
  postURL: (boardID, threadID, postID) ->
    if Build.sameThread boardID, threadID
      "\#p#{postID}"
    else
      "/#{boardID}/thread/#{threadID}\#p#{postID}"
  postFromObject: (data, boardID) ->
    o =
      # id
      postID:   data.no
      threadID: data.resto or data.no
      boardID:  boardID
      # info
      name:     Build.unescape data.name
      capcode:  data.capcode
      tripcode: data.trip
      uniqueID: data.id
      email:    Build.unescape data.email
      subject:  Build.unescape data.sub
      flagCode: data.country
      flagName: Build.unescape data.country_name
      date:     data.now
      dateUTC:  data.time
      h_comment: data.com or ''
      # thread status
      isSticky: !!data.sticky
      isClosed: !!data.closed
      # file
    if data.filedeleted
      o.file =
        isDeleted: true
    else if data.ext
      o.file =
        name:      (Build.unescape data.filename) + data.ext
        timestamp: "#{data.tim}#{data.ext}"
        url: if boardID is 'f'
          "//i.4cdn.org/#{boardID}/#{encodeURIComponent data.filename}#{data.ext}"
        else
          "//i.4cdn.org/#{boardID}/#{data.tim}#{data.ext}"
        height:    data.h
        width:     data.w
        MD5:       data.md5
        size:      data.fsize
        turl:      "//#{Build.thumbRotate()}.t.4cdn.org/#{boardID}/#{data.tim}s.jpg"
        theight:   data.tn_h
        twidth:    data.tn_w
        isSpoiler: !!data.spoiler
        isDeleted: false
        tag:       data.tag
    Build.post o
  post: (o) ->
    ###
    This function contains code from 4chan-JS (https://github.com/4chan/4chan-JS).
    @license: https://github.com/4chan/4chan-JS/blob/master/LICENSE
    ###
    {
      postID, threadID, boardID
      name, capcode, tripcode, uniqueID, email, subject, flagCode, flagName, date, dateUTC
      isSticky, isClosed
      file
    } = o
    name    or= ''
    subject or= ''
    h_comment = o.h_comment
    isOP = postID is threadID

    if Build.initPixelRatio >= 2
      h_retina = '@2x'
    else
      h_retina = ''

    ### Name Block ###

    switch capcode
      when 'admin', 'admin_highlight'
        h_capcodeClass = ' capcodeAdmin'
        h_capcodeStart = ' <strong class="capcode hand id_admin" title="Highlight posts by the Administrator">## Admin</strong>'
        h_capcodeIcon  = "<img src='//s.4cdn.org/image/adminicon#{h_retina}.gif' alt='Admin Icon' title='This user is the 4chan Administrator.' class='identityIcon retina'>"
      when 'mod'
        h_capcodeClass = ' capcodeMod'
        h_capcodeStart = ' <strong class="capcode hand id_mod" title="Highlight posts by Moderators">## Mod</strong>'
        h_capcodeIcon  = "<img src='//s.4cdn.org/image/modicon#{h_retina}.gif' alt='Mod Icon' title='This user is a 4chan Moderator.' class='identityIcon retina'>"
      when 'developer'
        h_capcodeClass = ' capcodeDeveloper'
        h_capcodeStart = ' <strong class="capcode hand id_developer" title="Highlight posts by Developers">## Developer</strong>'
        h_capcodeIcon  = "<img src='//s.4cdn.org/image/developericon#{h_retina}.gif' alt='Developer Icon' title='This user is a 4chan Developer.' class='identityIcon retina'>"
      else
        h_capcodeClass = ''
        h_capcodeStart = ''
        h_capcodeIcon  = ''

    if capcode
      h_nameClass = ' capcode'
    else
      h_nameClass = ''

    if tripcode
      h_tripcode = " <span class='postertrip'>#{E tripcode}</span>"
    else
      h_tripcode = ''

    h_emailCont = "<span class='name#{h_nameClass}'>#{E name}</span>#{h_tripcode}#{h_capcodeStart}"
    if email
      emailProcessed = encodeURIComponent(email).replace /%40/g, '@'
      h_email = "<a href='mailto:#{E emailProcessed}' class='useremail'>#{h_emailCont}</a>"
    else
      h_email = h_emailCont
    unless isOP and boardID is 'f'
      h_email += ' '

    if !capcode and uniqueID
      h_userID = " <span class='posteruid id_#{E uniqueID}'>(ID: <span class='hand' title='Highlight posts by this ID'>#{E uniqueID}</span>)</span>"
    else
      h_userID = ''

    unless flagCode
      h_flag = ''
    else
      flagCodeLC = flagCode.toLowerCase()
      if boardID is 'pol'
        h_flag = "<img src='//s.4cdn.org/image/country/troll/#{E flagCodeLC}.gif' alt='#{E flagCode}' title='#{E flagName}' class='countryFlag'>"
      else
        h_flag = "<span title='#{E flagName}' class='flag flag-#{E flagCodeLC}'></span>"

    h_nameBlock  =   "<span class='nameBlock#{h_capcodeClass}'>"
    h_nameBlock +=     "#{h_email}#{h_capcodeIcon}#{h_userID}#{h_flag}"
    h_nameBlock +=   '</span> '

    ### Post Info ###

    if isOP or boardID is 'f'
      h_subject = "<span class='subject'>#{E subject}</span> "
    else
      h_subject = ''

    if isOP and boardID is 'f'
      h_desktop2 = ''
    else
      h_desktop2 = ' desktop'

    postLink = Build.postURL boardID, threadID, postID
    quoteLink = if Build.sameThread boardID, threadID
      "javascript:quote('#{+postID}');"
    else
      "/#{boardID}/thread/#{threadID}\#q#{postID}"

    if isOP and g.VIEW is 'index' and Conf['JSON Navigation']
      pageNum   = Math.floor(Index.liveThreadIDs.indexOf(postID) / Index.threadsNumPerPage) + 1
      h_pageIcon  = " <span class='page-num' title='This thread is on page #{+pageNum} in the original index.'>[#{+pageNum}]</span>"
    else
      h_pageIcon = ''

    if isSticky
      h_sticky = " <img src='//s.4cdn.org/image/sticky#{h_retina}.gif' alt='Sticky' title='Sticky' class='stickyIcon retina'>"
    else
      h_sticky = ''

    if isClosed
      h_closed = " <img src='//s.4cdn.org/image/closed#{h_retina}.gif' alt='Closed' title='Closed' class='closedIcon retina'>"
    else
      h_closed = ''

    if isOP and g.VIEW is 'index'
      h_replyLink = " &nbsp; <span>[<a href='/#{E boardID}/thread/#{+threadID}' class='replylink'>Reply</a>]</span>"
    else
      h_replyLink = ''

    h_postInfo  = "<div class='postInfo desktop' id='pi#{+postID}'>"
    h_postInfo +=   "<input type='checkbox' name='#{+postID}' value='delete'> "
    h_postInfo +=   h_subject
    h_postInfo +=   h_nameBlock
    h_postInfo +=   "<span class='dateTime' data-utc='#{+dateUTC}'>#{E date}</span> "
    h_postInfo +=   "<span class='postNum#{h_desktop2}'>"
    h_postInfo +=     "<a href='#{E postLink}' title='Link to this post'>No.</a>"
    h_postInfo +=     "<a href='#{E quoteLink}' title='Reply to this post'>#{+postID}</a>"
    h_postInfo +=     "#{h_pageIcon}#{h_sticky}#{h_closed}#{h_replyLink}"
    h_postInfo +=   '</span>'
    h_postInfo += '</div>'

    ### File Info ###

    if file?.isDeleted
      h_fileCont  = '<span class="fileThumb">'
      h_fileCont +=   "<img src='//s.4cdn.org/image/filedeleted-res#{h_retina}.gif' alt='File deleted.' class='fileDeletedRes retina'>"
      h_fileCont += '</span>'
    else if file and boardID is 'f'
      fileSize  = $.bytesToString file.size
      h_fileCont  = "<div class='fileInfo'><span class='fileText' id='fT#{+postID}'>"
      h_fileCont +=   "File: <a data-width='#{+file.width}' data-height='#{+file.height}' href='#{E file.url}' target='_blank'>#{E file.name}</a>"
      h_fileCont +=    "-(#{E fileSize}, #{+file.width}x#{+file.height}, #{E file.tag})"
      h_fileCont += '</span></div>'
    else if file
      if file.isSpoiler
        h_fileTitle1 = "title='#{E file.name}'"
        shortFilename = 'Spoiler Image'
        h_spoilerClass = ' imgspoiler'
        if spoilerRange = Build.spoilerRange[boardID]
          # Randomize the spoiler image.
          fileThumb = "//s.4cdn.org/image/spoiler-#{boardID}#{Math.floor 1 + spoilerRange * Math.random()}.png"
        else
          fileThumb = '//s.4cdn.org/image/spoiler.png'
        file.twidth = file.theight = 100
      else
        h_fileTitle1 = ''
        shortFilename = Build.shortFilename file.name, !isOP
        h_spoilerClass = ''
        fileThumb = file.turl

      if file.isSpoiler or file.name is shortFilename
        h_fileTitle2 = ''
      else
        h_fileTitle2 = "title='#{E file.name}'"

      fileSize  = $.bytesToString file.size

      if file.url[-4..] is '.pdf'
        h_fileDims = 'PDF'
      else
        h_fileDims = "#{+file.width}x#{+file.height}"

      h_fileCont  = "<div class='fileText' id='fT#{+postID}' #{h_fileTitle1}>"
      h_fileCont +=   "File: <a #{h_fileTitle2} href='#{E file.url}' target='_blank'>#{E shortFilename}</a> (#{E fileSize}, #{h_fileDims})"
      h_fileCont += '</div>'
      h_fileCont += "<a class='fileThumb#{h_spoilerClass}' href='#{E file.url}' target='_blank'>"
      h_fileCont +=   "<img src='#{E fileThumb}' alt='#{E fileSize}' data-md5='#{E file.MD5}' style='height: #{+file.theight}px; width: #{+file.twidth}px;'>"
      h_fileCont += '</a>'

    if file
      h_file = "<div class='file' id='f#{+postID}'>#{h_fileCont}</div>"
    else
      h_file = ''

    ### Whole Post ###

    if capcode is 'admin_highlight'
      h_highlightPost = ' highlightPost'
    else
      h_highlightPost = ''

    h_message = "<blockquote class='postMessage' id='m#{+postID}'>#{h_comment}</blockquote>"

    if isOP
      h_post  = "<div id='p#{+postID}' class='post op#{h_highlightPost}'>"
      h_post +=   "#{h_file}#{h_postInfo}#{h_message}"
      h_post += '</div>'
    else
      h_post  = "<div class='sideArrows' id='sa#{+postID}'>&gt;&gt;</div>"
      h_post += "<div id='p#{+postID}' class='post reply#{h_highlightPost}'>"
      h_post +=   "#{h_postInfo}#{h_file}#{h_message}"
      h_post += '</div>'

    container = $.el 'div',
      className: "postContainer #{if isOP then 'op' else 'reply'}Container"
      id:        "pc#{postID}"
      innerHTML: h_post

    # Fix pathnames
    for quote in $$ '.quotelink', container
      href = quote.getAttribute 'href'
      if (href[0] is '#') and !(Build.sameThread boardID, threadID)
        quote.href = "/#{boardID}/thread/#{threadID}" + href
      else if (match = href.match /^\/([^\/]+)\/thread\/(\d+)/) and (Build.sameThread match[1], match[2])
        quote.href = href.match(/(#[^#]*)?$/)[0] or '#'

    container

  summary: (boardID, threadID, posts, files) ->
    text = []
    text.push "#{posts} post#{if posts > 1 then 's' else ''}"
    text.push "and #{files} image repl#{if files > 1 then 'ies' else 'y'}" if files
    text.push 'omitted.'
    $.el 'a',
      className: 'summary'
      textContent: text.join ' '
      href: "/#{boardID}/thread/#{threadID}"

  thread: (board, data, full) ->
    Build.spoilerRange[board] = data.custom_spoiler

    if (OP = board.posts[data.no]) and root = OP.nodes.root.parentNode
      $.rmAll root
    else
      root = $.el 'div',
        className: 'thread'
        id: "t#{data.no}"

    $.add root, Build[if full then 'fullThread' else 'excerptThread'] board, data, OP
    root

  excerptThread: (board, data, OP) ->
    nodes = [if OP then OP.nodes.root else Build.postFromObject data, board.ID]
    if data.omitted_posts or !Conf['Show Replies'] and data.replies
      [posts, files] = if Conf['Show Replies']
        [data.omitted_posts, data.omitted_images]
      else
        # XXX data.images is not accurate.
        [data.replies, data.omitted_images + data.last_replies.filter((data) -> !!data.ext).length]
      nodes.push Build.summary board.ID, data.no, posts, files
    nodes

  fullThread: (board, data) -> Build.postFromObject data, board.ID
