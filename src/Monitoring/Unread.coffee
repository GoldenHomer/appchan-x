Unread =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Unread Count'] and !Conf['Unread Favicon'] and !Conf['Desktop Notifications']

    @db = new DataBoard 'lastReadPosts', @sync
    @hr = $.el 'hr',
      id: 'unread-line'
    @posts = new RandomAccessList
    @postsQuotingYou = []

    Thread.callbacks.push
      name: 'Unread'
      cb:   @node

  disconnect: ->
    return if g.VIEW isnt 'thread' or !Conf['Unread Count'] and !Conf['Unread Favicon'] and !Conf['Desktop Notifications']

    Unread.db.disconnect()
    {hr} = Unread
    $.rm hr if hr

    delete @[name] for name in ['db', 'hr', 'posts', 'postsQuotingYou', 'thread', 'title']
    @lastReadPost = 0

    $.off d, '4chanXInitFinished',      @ready
    $.off d, 'ThreadUpdate',            @onUpdate
    $.off d, 'scroll visibilitychange', @read
    $.off d, 'visibilitychange',        @setLine if Conf['Unread Line']

    Thread.callbacks.disconnect 'Unread'

  node: ->
    Unread.thread = @
    Unread.title  = d.title
    Unread.lastReadPost = Unread.db.get
      boardID:      @board.ID
      threadID:     @ID
      defaultValue: 0
    $.on d, '4chanXInitFinished',      Unread.ready
    $.on d, 'ThreadUpdate',            Unread.onUpdate
    $.on d, 'scroll visibilitychange', Unread.read
    $.on d, 'visibilitychange',        Unread.setLine if Conf['Unread Line']

  ready: ->
    $.off d, '4chanXInitFinished', Unread.ready
    {posts} = Unread.thread
    post = posts.first().nodes.root
    # XXX I'm guessing the browser isn't reflowing fast enough?
    $.asap (-> post.getBoundingClientRect().bottom), ->
      if Conf['Quote Threading']
        QuoteThreading.force()
      else
        arr = []
        posts.forEach (post) -> arr.push post if post.isReply
        Unread.addPosts arr
      setTimeout Unread.scroll, 200 if Conf['Scroll to Last Read Post']

  scroll: ->
    # Let the header's onload callback handle it.
    return if (hash = location.hash.match /\d+/) and hash[0] of Unread.thread.posts
    if post = Unread.posts.first
      # Scroll to a non-hidden, non-OP post that's before the first unread post.
      while root = $.x 'preceding-sibling::div[contains(@class,"replyContainer")][1]', post.data.nodes.root
        break unless (post = Get.postFromRoot root).isHidden
      return unless root
      down = true
    else
      # Scroll to the last read post.
      {posts} = Unread.thread
      {keys}  = posts
      {root}  = posts[keys[keys.length - 1]].nodes

    # Scroll to the target unless we scrolled past it.
    Header.scrollTo root, down if Header.getBottomOf(root) < 0

  sync: ->
    lastReadPost = Unread.db.get
      boardID:      Unread.thread.board.ID
      threadID:     Unread.thread.ID
      defaultValue: 0

    return if Unread.lastReadPost > lastReadPost

    Unread.lastReadPost = lastReadPost
    post = Unread.posts.first
    while post
      {ID} = post
      break if ID > lastReadPost
      post = post.next
      Unread.posts.rm ID

    Unread.readArray Unread.postsQuotingYou
    Unread.setLine() if Conf['Unread Line']
    Unread.update()

  addPosts: (posts) ->
    for post in posts
      {ID} = post
      continue if ID <= Unread.lastReadPost or post.isHidden or QR.db.get {
        boardID:  post.board.ID
        threadID: post.thread.ID
        postID:   ID
      }
      Unread.posts.push post
      Unread.addPostQuotingYou post
    if Conf['Unread Line']
      # Force line on visible threads if there were no unread posts previously.
      Unread.setLine Unread.posts.first?.data in posts
    Unread.read()
    Unread.update()

  addPostQuotingYou: (post) ->
    for quotelink in post.nodes.quotelinks when QR.db.get Get.postDataFromLink quotelink
      Unread.postsQuotingYou.push post
      Unread.openNotification post
      return

  openNotification: (post) ->
    return unless Header.areNotificationsEnabled
    notif = new Notification "#{post.getNameBlock()} replied to you",
      body: post.info.comment
      icon: Favicon.logo
    notif.onclick = ->
      Header.scrollToIfNeeded post.nodes.root, true
      window.focus()
    notif.onshow = ->
      setTimeout ->
        notif.close()
      , 7 * $.SECOND

  onUpdate: (e) ->
    if e.detail[404]
      Unread.update()
    else if Conf['Quote Threading']
      Unread.read()
      Unread.update()
    else
      Unread.addPosts [].map.call e.detail.newPosts, (fullID) -> g.posts[fullID]

  readSinglePost: (post) ->
    {ID} = post
    {posts} = Unread
    return unless posts[ID]
    if post is posts.first
      Unread.lastReadPost = ID
      Unread.saveLastReadPost()
    posts.rm ID
    if (i = Unread.postsQuotingYou.indexOf post) isnt -1
      Unread.postsQuotingYou.splice i, 1
    Unread.update()

  readArray: (arr) ->
    for post, i in arr
      break if post.ID > Unread.lastReadPost
    arr.splice 0, i

  read: $.debounce 100, (e) ->
    return if d.hidden or !Unread.posts.length
    {posts} = Unread

    while post = posts.first
      break unless Header.getBottomOf(post.data.nodes.root) > -1 # post is not completely read
      {ID, data} = post
      posts.rm ID

      if Conf['Mark Quotes of You'] and QR.db.get {
        boardID:  data.board.ID
        threadID: data.thread.ID
        postID:   ID
      }
        QuoteMarkers.lastRead = data.nodes.root

    return unless ID

    Unread.lastReadPost = ID if Unread.lastReadPost < ID
    Unread.saveLastReadPost()
    Unread.readArray Unread.postsQuotingYou
    Unread.update() if e

  saveLastReadPost: $.debounce 5 * $.SECOND, ->
    return if Unread.thread.isDead
    Unread.db.set
      boardID:  Unread.thread.board.ID
      threadID: Unread.thread.ID
      val:      Unread.lastReadPost

  setLine: (force) ->
    return unless d.hidden or force is true
    return $.rm Unread.hr unless post = Unread.posts.first
    if $.x 'preceding-sibling::div[contains(@class,"replyContainer")]', post.data.nodes.root # not the first reply
      $.before post.data.nodes.root, Unread.hr

  update: ->
    count = Unread.posts.length

    if Conf['Unread Count']
      d.title = "#{if count or !Conf['Hide Unread Count at (0)'] then "(#{count}) " else ''}#{if g.DEAD then Unread.title.replace '-', '- 404 -' else Unread.title}"

    return unless Conf['Unread Favicon']

    Favicon.el.href =
      if g.DEAD
        if Unread.postsQuotingYou[0]
          Favicon.unreadDeadY
        else if count
          Favicon.unreadDead
        else
          Favicon.dead
      else
        if count
          if Unread.postsQuotingYou[0]
            Favicon.unreadY
          else
            Favicon.unread
        else
          Favicon.default

    <% if (type === 'userscript') { %>
    # `favicon.href = href` doesn't work on Firefox.
    $.add d.head, Favicon.el
    <% } %>
