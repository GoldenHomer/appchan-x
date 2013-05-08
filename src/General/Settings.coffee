Settings =
  init: ->
    # Appchan X settings link
    link = $.el 'a',
      id:          'appchanOptions'
      className:   'settings-link'
      href:        'javascript:;'
    $.on link, 'click', Settings.open

    $.asap (-> d.body), ->
      return unless Main.isThisPageLegit()
      # Wait for #boardNavMobile instead of #boardNavDesktop,
      # it might be incomplete otherwise.
      $.add d.body, link

    $.get 'previousversion', null, (item) ->
      if previous = item['previousversion']
        return if previous is g.VERSION
        # Avoid conflicts between sync'd newer versions
        # and out of date extension on this device.
        prev = previous.match(/\d+/g).map Number
        curr = g.VERSION.match(/\d+/g).map Number
        return unless prev[0] <= curr[0] and prev[1] <= curr[1] and prev[2] <= curr[2]

        changelog = '<%= meta.repo %>blob/<%= meta.mainBranch %>/CHANGELOG.md'
        el = $.el 'span',
          innerHTML: "<%= meta.name %> has been updated to <a href='#{changelog}' target=_blank>version #{g.VERSION}</a>."
        new Notification 'info', el, 30
      else
        $.on d, '4chanXInitFinished', Settings.open
      $.set
        lastupdate: Date.now()
        previousversion: g.VERSION

    Settings.addSection 'Style',    Settings.style
    Settings.addSection 'Themes',   Settings.themes
    Settings.addSection 'Mascots',  Settings.mascots
    Settings.addSection 'Script',   Settings.main
    Settings.addSection 'Filter',   Settings.filter
    Settings.addSection 'Sauce',    Settings.sauce
    Settings.addSection 'Advanced', Settings.advanced
    Settings.addSection 'Keybinds', Settings.keybinds

    $.on d, 'AddSettingsSection',   Settings.addSection
    $.on d, 'OpenSettings',         (e) -> Settings.open e.detail

    settings = JSON.parse(localStorage.getItem '4chan-settings') or {}
    return if settings.disableAll
    settings.disableAll = true
    localStorage.setItem '4chan-settings', JSON.stringify settings

  open: (openSection) ->
    if Conf['editMode'] is "theme"
      if confirm "Opening the options dialog will close and discard any theme changes made with the theme editor."
        ThemeTools.close()
      return

    if Conf['editMode'] is "mascot"
      if confirm "Opening the options dialog will close and discard any mascot changes made with the mascot editor."
        MascotTools.close()
      return

    return if Settings.overlay
    $.event 'CloseMenu'

    Settings.dialog = dialog = $.el 'div',
      id:    'appchanx-settings'
      class: 'dialog'
      innerHTML: """<%= grunt.file.read('src/General/html/Settings/Settings.html').replace(/>\s+</g, '><').trim() %>"""

    Settings.overlay = overlay = $.el 'div',
      id: 'overlay'

    $.on $('.export', dialog), 'click',  Settings.export
    $.on $('.import', dialog), 'click',  Settings.import
    $.on $('input',   dialog), 'change', Settings.onImport

    links = []
    for section in Settings.sections
      link = $.el 'a',
        className: "tab-#{section.hyphenatedTitle}"
        textContent: section.title
        href: 'javascript:;'
      $.on link, 'click', Settings.openSection.bind section
      links.push link
      sectionToOpen = link if section.title is openSection
    $.add $('.sections-list', dialog), links
    (if sectionToOpen then sectionToOpen else links[0]).click()

    $.on $('.close', dialog), 'click', Settings.close
    $.on overlay,             'click', Settings.close

    $.add d.body, [overlay, dialog]

  close: ->
    return unless Settings.dialog
    $.rm Settings.overlay
    $.rm Settings.dialog
    delete Settings.overlay
    delete Settings.dialog

  sections: []

  addSection: (title, open) ->
    if typeof title isnt 'string'
      {title, open} = title.detail
    hyphenatedTitle = title.toLowerCase().replace /\s+/g, '-'
    Settings.sections.push {title, hyphenatedTitle, open}

  openSection: (mode) ->
    if selected = $ '.tab-selected', Settings.dialog
      $.rmClass selected, 'tab-selected'
    $.addClass $(".tab-#{@hyphenatedTitle}", Settings.dialog), 'tab-selected'
    section = $ 'section', Settings.dialog
    $.rmAll section
    section.className = "section-#{@hyphenatedTitle}"
    @open section, mode
    section.scrollTop = 0

  main: (section) ->
    items  = {}
    inputs = {}
    for key, obj of Config.main
      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"
      for key, arr of obj
        description = arr[1]
        div = $.el 'div',
          innerHTML: "<label><input type=checkbox name='#{key}'>#{key}</label><span class=description>#{description}</span>"
        input = $ 'input', div
        $.on $('label', div), 'mouseover', Settings.mouseover
        $.on input, 'change', $.cb.checked
        items[key]  = Conf[key]
        inputs[key] = input
        $.add fs, div
      Rice.nodes fs
      $.add section, fs

    $.get items, (items) ->
      for key, val of items
        inputs[key].checked = val
      return

    div = $.el 'div',
      innerHTML: "<button></button><span class=description>: Clear manually-hidden threads and posts on all boards. Refresh the page to apply."
    button = $ 'button', div
    hiddenNum = 0
    $.get 'hiddenThreads', boards: {}, (item) ->
      for ID, board of item.hiddenThreads.boards
        for ID, thread of board
          hiddenNum++
      button.textContent = "Hidden: #{hiddenNum}"
    $.get 'hiddenPosts', boards: {}, (item) ->
      for ID, board of item.hiddenPosts.boards
        for ID, thread of board
          for ID, post of thread
            hiddenNum++
      button.textContent = "Hidden: #{hiddenNum}"
    $.on button, 'click', ->
      @textContent = 'Hidden: 0'
      $.get 'hiddenThreads', boards: {}, (item) ->
        for boardID of item.hiddenThreads.boards
          localStorage.removeItem "4chan-hide-t-#{boardID}"
        $.delete ['hiddenThreads', 'hiddenPosts']
    $.after $('input[name="Stubs"]', section).parentNode.parentNode, div

  export: (now, data) ->
    unless typeof now is 'number'
      now  = Date.now()
      data =
        version: g.VERSION
        date: now
      Conf['WatchedThreads'] = {}
      for db in DataBoards
        Conf[db] = boards: {}
      # Make sure to export the most recent data.
      $.get Conf, (Conf) ->
        data.Conf = Conf
        Settings.export now, data
      return
    a = $.el 'a',
      className: 'warning'
      textContent: 'Save me!'
      download: "<%= meta.name %> v#{g.VERSION}-#{now}.json"
      href: "data:application/json;base64,#{btoa unescape encodeURIComponent JSON.stringify data, null, 2}"
      target: '_blank'
    <% if (type !== 'userscript') { %>
    a.click()
    return
    <% } %>
    # XXX Firefox won't let us download automatically.
    span = $ '.imp-exp-result', Settings.dialog
    $.rmAll span
    $.add span, a

  import: ->
    @nextElementSibling.click()

  onImport: ->
    return unless file = @files[0]
    output = $('.imp-exp-result')
    unless confirm 'Your current settings will be entirely overwritten, are you sure?'
      output.textContent = 'Import aborted.'
      return
    reader = new FileReader()
    reader.onload = (e) ->
      try
        data = JSON.parse e.target.result
        Settings.loadSettings data
        if confirm 'Import successful. Refresh now?'
          window.location.reload()
      catch err
        output.textContent = 'Import failed due to an error.'
        c.error err.stack
    reader.readAsText file

  loadSettings: (data) ->
    version = data.version.split '.'
    if version[0] is '2'
      data = Settings.convertSettings data,
        # General confs
        'Disable 4chan\'s extension': ''
        'Catalog Links': ''
        'Reply Navigation': ''
        'Show Stubs': 'Stubs'
        'Image Auto-Gif': 'Auto-GIF'
        'Expand From Current': ''
        'Unread Tab Icon': 'Unread Favicon'
        'Post in Title': 'Thread Excerpt'
        'Auto Hide QR': ''
        'Open Reply in New Tab': ''
        'Remember QR size': ''
        'Quote Inline': 'Quote Inlining'
        'Quote Preview': 'Quote Previewing'
        'Indicate OP quote': 'Mark OP Quotes'
        'Indicate Cross-thread Quotes': 'Mark Cross-thread Quotes'
        'Reply Hiding': 'Reply Hiding Buttons'
        'Thread Hiding': 'Thread Hiding Buttons'
        # filter
        'uniqueid': 'uniqueID'
        'mod': 'capcode'
        'country': 'flag'
        'md5': 'MD5'
        # keybinds
        'openEmptyQR': 'Open empty QR'
        'openQR': 'Open QR'
        'openOptions': 'Open settings'
        'close': 'Close'
        'spoiler': 'Spoiler tags'
        'code': 'Code tags'
        'submit': 'Submit QR'
        'watch': 'Watch'
        'update': 'Update'
        'unreadCountTo0': ''
        'expandAllImages': 'Expand images'
        'expandImage': 'Expand image'
        'zero': 'Front page'
        'nextPage': 'Next page'
        'previousPage': 'Previous page'
        'nextThread': 'Next thread'
        'previousThread': 'Previous thread'
        'expandThread': 'Expand thread'
        'openThreadTab': 'Open thread'
        'openThread': 'Open thread tab'
        'nextReply': 'Next reply'
        'previousReply': 'Previous reply'
        'hide': 'Hide'
        # updater
        'Scrolling': 'Auto Scroll'
        'Verbose': ''
      data.Conf.sauces = data.Conf.sauces.replace /\$\d/g, (c) ->
        switch c
          when '$1'
            '%TURL'
          when '$2'
            '%URL'
          when '$3'
            '%MD5'
          when '$4'
            '%board'
          else
            c
      for key, val of Config.hotkeys
        continue unless key of data.Conf
        data.Conf[key] = data.Conf[key].replace(/ctrl|alt|meta/g, (s) -> "#{s[0].toUpperCase()}#{s[1..]}").replace /(^|.+\+)[A-Z]$/g, (s) ->
          "Shift+#{s[0...-1]}#{s[-1..].toLowerCase()}"
      data.Conf.WatchedThreads = data.WatchedThreads
    else if version[0] is '3'
      data = Settings.convertSettings data,
        'Reply Hiding': 'Reply Hiding Buttons'
        'Thread Hiding': 'Thread Hiding Buttons'
        'Bottom header': 'Bottom Header'
        'Unread Tab Icon': 'Unread Favicon'
    $.set data.Conf

  convertSettings: (data, map) ->
    for prevKey, newKey of map
      data.Conf[newKey] = data.Conf[prevKey] if newKey
      delete data.Conf[prevKey]
    data

  filter: (section) ->
    section.innerHTML = """
    <%= grunt.file.read('src/General/html/Settings/Filter-select.html').replace(/>\s+</g, '><').trim() %>
    """
    select = $ 'select', section
    $.on select, 'change', Settings.selectFilter
    Settings.selectFilter.call select

  selectFilter: ->
    div = @nextElementSibling
    if (name = @value) isnt 'guide'
      $.rmAll div
      ta = $.el 'textarea',
        name: name
        className: 'field'
        spellcheck: false
      $.get name, Conf[name], (item) ->
        ta.value = item[name]
      $.on ta, 'change', $.cb.value
      $.add div, ta
      return
    div.innerHTML = """
    <%= grunt.file.read('src/General/html/Settings/Filter-guide.html').replace(/>\s+</g, '><').trim() %>
    """

  sauce: (section) ->
    section.innerHTML = """
    <%= grunt.file.read('src/General/html/Settings/Sauce.html').replace(/>\s+</g, '><').trim() %>
    """
    ta = $ 'textarea', section
    $.get 'sauces', Conf['sauces'], (item) ->
      ta.value = item['sauces']
    $.on ta, 'change', $.cb.value

  advanced: (section) ->
    section.innerHTML = """<%= grunt.file.read('src/General/html/Settings/Advanced.html').replace(/>\s+</g, '><').trim() %>"""
    items = {}
    inputs = {}
    for name in ['boardnav', 'time', 'backlink', 'fileInfo', 'favicon', 'emojiPos', 'sageEmoji', 'usercss']
      input = $ "[name='#{name}']", section
      items[name]  = Conf[name]
      inputs[name] = input
      event = if ['favicon', 'usercss', 'sageEmoji', 'emojiPos'].contains name
        'change'
      else
        'input'
      $.on input, event, $.cb.value

    # Quick Reply Personas
    ta = $ '.personafield', section
    $.get 'QR.personas', Conf['QR.personas'], (item) ->
      ta.value = item['QR.personas']
    $.on ta, 'change', $.cb.value

    # Archiver
    archiver = $ 'select[name=archiver]', section
    toSelect = Redirect.select g.BOARD.ID
    toSelect = ['No Archive Available'] unless toSelect[0]

    $.add archiver, $.el('option', {textContent: name}) for name in toSelect

    if toSelect[1]
      Conf['archivers'][g.BOARD]
      archiver.value = Conf['archivers'][g.BOARD] or toSelect[0]
      $.on archiver, 'change', ->
        Conf['archivers'][g.BOARD] = @value
        $.set 'archivers', Conf.archivers

    $.get items, (items) ->
      for key, val of items
        continue if ['emojiPos', 'archiver'].contains key
        input = inputs[key]
        input.value = val
        continue if key is 'usercss'
        $.on input, event, Settings[key]
        Settings[key].call input
      Rice.nodes sectionreturn

    $.on $('input[name=Interval]', section), 'change', ThreadUpdater.cb.interval
    $.on $('input[name="Custom CSS"]', section), 'change', Settings.togglecss
    $.on $.id('apply-css'), 'click', Settings.usercss

  boardnav: ->
    Header.generateBoardList @value

  time: ->
    funk = Time.createFunc @value
    @nextElementSibling.textContent = funk Time, new Date()

  backlink: ->
    @nextElementSibling.textContent = @value.replace /%id/, '123456789'

  fileInfo: ->
    data =
      isReply: true
      file:
        URL: '//images.4chan.org/g/src/1334437723720.jpg'
        name: 'd9bb2efc98dd0df141a94399ff5880b7.jpg'
        size: '276 KB'
        sizeInBytes: 276 * 1024
        dimensions: '1280x720'
        isImage: true
        isSpoiler: true
    funk = FileInfo.createFunc @value
    @nextElementSibling.innerHTML = funk FileInfo, data

  favicon: ->
    Favicon.switch()
    Unread.update() if g.VIEW is 'thread' and Conf['Unread Favicon']
    $.id('favicon-preview').innerHTML = """
      <img src=#{Favicon.default}>
      <img src=#{Favicon.unreadSFW}>
      <img src=#{Favicon.unreadNSFW}>
      <img src=#{Favicon.unreadDead}>
      """

  sageEmoji: ->
    $.id('sageicon-preview').innerHTML = """
      <img src=data:image/png;base64,#{Emoji.sage[@value]}>
      """

  togglecss: ->
    if $('textarea', @parentNode.parentNode).disabled = !@checked
      CustomCSS.rmStyle()
    else
      CustomCSS.addStyle()
    $.cb.checked.call @

  usercss: ->
    CustomCSS.update()

  keybinds: (section) ->
    section.innerHTML = """
    <%= grunt.file.read('src/General/html/Settings/Keybinds.html').replace(/>\s+</g, '><').trim() %>
    """
    tbody  = $ 'tbody', section
    items  = {}
    inputs = {}
    for key, arr of Config.hotkeys
      tr = $.el 'tr',
        innerHTML: "<td>#{arr[1]}</td><td><input class=field></td>"
      input = $ 'input', tr
      input.name = key
      input.spellcheck = false
      items[key]  = Conf[key]
      inputs[key] = input
      $.on input, 'keydown', Settings.keybind
      Rice.nodes tr
      $.add tbody, tr

    $.get items, (items) ->
      for key, val of items
        inputs[key].value = val
      return

  keybind: (e) ->
    return if e.keyCode is 9 # tab
    e.preventDefault()
    e.stopPropagation()
    return unless (key = Keybinds.keyCode e)?
    @value = key
    $.cb.value.call @

  style: (section) ->
    nodes  = $.frag()
    items  = {}
    inputs = {}

    for key, obj of Config.style

      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"

      for key, arr of obj
        [value, description, type] = arr

        div = $.el 'div',
          className: 'styleoption'

        if type

          if type is 'text'

            div.innerHTML = "<div class=option><span class=optionlabel>#{key}</span></div><div class=description>#{description}</div><div class=option><input name='#{key}' style=width: 100%></div>"
            input = $ "input", div

          else

            html = "<div class=option><span class=optionlabel>#{key}</span></div><div class=description>#{description}</div><div class=option><select name='#{key}'>"
            for name in type
              html += "<option value='#{name}'>#{name}</option>"
            html += "</select></div>"
            div.innerHTML = html
            input = $ "select", div

        else

          div.innerHTML = "<div class=option><label><input type=checkbox name='#{key}'>#{key}</label></div><span style='display:none;'>#{description}</span>"
          input = $ 'input', div
          input.bool = true

        items[key]  = Conf[key]
        inputs[key] = input

        $.on $('.option', div), 'mouseover', Settings.mouseover

        $.on input, 'change', Settings.change

        $.add fs, div
      $.add nodes, fs

    $.get items, (items) ->
      for key, val of items
        input = inputs[key]
        if input.bool
          input.checked = val
          Rice.checkbox input
        else
          input.value   = val
          if input.nodeName is 'SELECT'
            Rice.select input

      $.add section, nodes


  change: ->
    $.cb[if @bool then 'checked' else 'value'].call @
    Style.addStyle()

  themes: (section, mode) ->
    if typeof mode isnt 'string'
      mode = 'default'

    parentdiv  = $.el 'div',
      id:        "themeContainer"

    suboptions = $.el 'div',
      className: "suboptions"
      id:        "themes"

    keys = Object.keys(Themes)
    keys.sort()

    cb = Settings.cb.theme

    if mode is "default"

      for name in keys
        theme = Themes[name]

        continue if theme["Deleted"]

        div = $.el 'div',
          className: "theme #{if name is Conf['theme'] then 'selectedtheme' else ''}"
          id:        name
          innerHTML: "
<div style='cursor: pointer; position: relative; margin-bottom: 2px; width: 100% !important; box-shadow: none !important; background:#{theme['Reply Background']}!important;border:1px solid #{theme['Reply Border']}!important;color:#{theme['Text']}!important'>
  <div>
    <div style='cursor: pointer; width: 9px; height: 9px; margin: 2px 3px; display: inline-block; vertical-align: bottom; background: #{theme['Checkbox Background']}; border: 1px solid #{theme['Checkbox Border']};'></div>
    <span style='color:#{theme['Subjects']}!important; font-weight: 600 !important'>
      #{name}
    </span>
    <span style='color:#{theme['Names']}!important; font-weight: 600 !important'>
      #{theme['Author']}
    </span>
    <span style='color:#{theme['Sage']}!important'>
      (SAGE)
    </span>
    <span style='color:#{theme['Tripcodes']}!important'>
      #{theme['Author Tripcode']}
    </span>
    <time style='color:#{theme['Timestamps']}'>
      20XX.01.01 12:00
    </time>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Post Numbers']}!important&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Post Numbers']}!important;' href='javascript:;'>
      No.27583594
    </a>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Backlinks']}!important;&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Backlinks']}!important;' href='javascript:;' name='#{name}' class=edit>
      &gt;&gt;edit
    </a>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Backlinks']}!important;&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Backlinks']}!important;' href='javascript:;' name='#{name}' class=export>
      &gt;&gt;export
    </a>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Backlinks']}!important;&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Backlinks']}!important;' href='javascript:;' name='#{name}' class=delete>
      &gt;&gt;delete
    </a>
  </div>
  <blockquote style='margin: 0; padding: 12px 40px 12px 38px'>
    <a style='color:#{theme['Quotelinks']}!important; text-shadow: none;'>
      &gt;&gt;27582902
    </a>
    <br>
    Post content is right here.
  </blockquote>
  <h1 style='color: #{theme['Text']}'>
    Selected
  </h1>
</div>"

        div.style.backgroundColor = theme['Background Color']

        $.on $('a.edit',   div), 'click', cb.edit
        $.on $('a.export', div), 'click', cb.export
        $.on $('a.delete', div), 'click', cb.delete
        $.on div,                'click', cb.select

        $.add suboptions, div

      div = $.el 'div',
        id:        'addthemes'
        innerHTML: "
<a id=newtheme href='javascript:;'>New Theme</a> /
 <a id=import href='javascript:;'>Import Theme</a><input id=importbutton type=file hidden> /
 <a id=SSimport href='javascript:;'>Import from 4chan SS</a><input id=SSimportbutton type=file hidden> /
 <a id=OCimport href='javascript:;'>Import from Oneechan</a><input id=OCimportbutton type=file hidden> /
 <a id=tUndelete href='javascript:;'>Undelete Theme</a>
"

      $.on $("#newtheme", div), 'click', ->
        ThemeTools.init "untitled"
        Settings.close()

      $.on $("#import", div), 'click', ->
        @nextSibling.click()
      $.on $("#importbutton", div), 'change', (e) ->
        ThemeTools.importtheme "appchan", e

      $.on $("#OCimport", div), 'click', ->
        @nextSibling.click()
      $.on $("#OCimportbutton", div), 'change', (e) ->
        ThemeTools.importtheme "oneechan", e

      $.on $("#SSimportbutton", div), 'change', (e) ->
        ThemeTools.importtheme "SS", e

      $.on $("#SSimport", div), 'click', ->
        @nextSibling.click()

      $.on $('#tUndelete', div), 'click', ->
        $.rm $.id "themeContainer"

        themes =
          open:            Settings.themes
          hyphenatedTitle: 'themes'

        Settings.openSection.apply themes, ['undelete']

    else

      for name in keys
        theme = Themes[name]

        continue unless theme["Deleted"]

        div = $.el 'div',
          id:        name
          className: theme
          innerHTML: "
<div style='cursor: pointer; position: relative; margin-bottom: 2px; width: 100% !important; box-shadow: none !important; background:#{theme['Reply Background']}!important;border:1px solid #{theme['Reply Border']}!important;color:#{theme['Text']}!important'>
  <div style='padding: 3px 0px 0px 8px;'>
    <span style='color:#{theme['Subjects']}!important; font-weight: 600 !important'>#{name}</span>
    <span style='color:#{theme['Names']}!important; font-weight: 600 !important'>#{theme['Author']}</span>
    <span style='color:#{theme['Sage']}!important'>(SAGE)</span>
    <span style='color:#{theme['Tripcodes']}!important'>#{theme['Author Tripcode']}</span>
    <time style='color:#{theme['Timestamps']}'>20XX.01.01 12:00</time>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Post Numbers']}!important&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important&quot;)' style='color:#{theme['Post Numbers']}!important;' href='javascript:;'>No.27583594</a>
  </div>
  <blockquote style='margin: 0; padding: 12px 40px 12px 38px'>
    <a style='color:#{theme['Quotelinks']}!important; text-shadow: none;'>
      &gt;&gt;27582902
    </a>
    <br>
    I forgive you for using VLC to open me. ;__;
  </blockquote>
</div>"

        $.on div, 'click', cb.restore

        $.add suboptions, div

      div = $.el 'div',
        id:        'addthemes'
        innerHTML: "<a href='javascript:;'>Return</a>"

      $.on $('a', div), 'click', ->
        themes =
          open:            Settings.themes
          hyphenatedTitle: 'themes'

        $.rm $.id "themeContainer"
        Settings.openSection.call themes

    $.add parentdiv, suboptions
    $.add parentdiv, div
    $.add section, parentdiv

  mouseover: (e) ->
    mouseover = $.el 'div',
      id:        'mouseover'
      className: 'dialog'

    $.add Header.hover, mouseover

    mouseover.innerHTML = @nextElementSibling.innerHTML

    UI.hover
      root:         @
      el:           mouseover
      latestEvent:  e
      endEvents:    'mouseout'
      asapTest: ->  true
      close:        true

    return

  mascots: (section, mode) ->
    categories = {}
    menu       = []
    cb         = Settings.cb.mascot

    if typeof mode isnt 'string'
      mode = 'default'

    suboptions = $.el "div",
      className: "suboptions"

    mascotHide = $.el "div",
      id: "mascot_hide"
      className: "reply"
      innerHTML: "Hide Categories <span class=drop-marker></span><div></div>"

    keys = Object.keys Mascots
    keys.sort()

    if mode is 'default'
      # Create a keyed Unordered List Element and hide option for each mascot category.
      nodes = {}
      for name in MascotTools.categories
        nodes[name] = []
        categories[name] = $.el "div",
          className: "mascots"
          id: name
          innerHTML: "<h3 class=mascotHeader>#{name}</h3>"

        if Conf["Hidden Categories"].contains name
          categories[name].hidden = true

        menu.push option = $.el "label",
          name: name
          innerHTML: "<input name='#{name}' type=checkbox #{if Conf["Hidden Categories"].contains(name) then 'checked' else ''}>#{name}"

        $.on $('input', option), 'change', cb.category

      for name in keys

        continue if Conf["Deleted Mascots"].contains name
        mascot = Mascots[name]
        mascotEl = $.el 'div',
          className: if Conf[g.MASCOTSTRING].contains name then 'mascot enabled' else 'mascot'
          id: name
          innerHTML: "<%= grunt.file.read('src/General/html/Settings/Mascot.html') %>"

        $.on $('.edit',   mascotEl), 'click', cb.edit
        $.on $('.delete', mascotEl), 'click', cb.delete
        $.on $('.export', mascotEl), 'click', cb.export

        $.on mascotEl, 'click', cb.select

        if MascotTools.categories.contains mascot.category
          nodes[mascot.category].push mascotEl
        else
          nodes[MascotTools.categories[0]].push mascotEl

      for name in MascotTools.categories
        $.add categories[name], nodes[name]
        $.add suboptions, categories[name]

      $.add $('div', mascotHide), menu

      batchmascots = $.el 'div',
        id: "mascots_batch"
        innerHTML: """<%= grunt.file.read('src/General/html/Settings/Batch-Mascot.html') %>"""

      $.on $('#clear', batchmascots), 'click', ->
        enabledMascots = JSON.parse(JSON.stringify(Conf[g.MASCOTSTRING]))
        for name in enabledMascots
          $.rmClass $.id(name), 'enabled'
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING] = []

      $.on $('#selectAll', batchmascots), 'click', ->
        for name, mascot of Mascots
          unless Conf["Hidden Categories"].contains(mascot.category) or Conf[g.MASCOTSTRING].contains(name) or Conf["Deleted Mascots"].contains(name)
            $.addClass $.id(name), 'enabled'
            Conf[g.MASCOTSTRING].push name
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING]

      $.on $('#createNew', batchmascots), 'click', ->
        MascotTools.dialog()
        Settings.close()

      $.on $("#importMascot", batchmascots), 'click', ->
        @nextSibling.click()

      $.on $("#importMascotButton", batchmascots), 'change', (e) ->
        MascotTools.importMascot e

      $.on $('#undelete', batchmascots), 'click', ->
        unless Conf["Deleted Mascots"].length > 0
          alert "No mascots have been deleted."
          return
        mascots =
          open:            Settings.mascots
          hyphenatedTitle: 'mascots'
        Settings.openSection.apply mascots, ['restore']

    else
      nodes = []
      categories = $.el "div",
        className: "mascots"

      for name in keys
        continue unless Conf["Deleted Mascots"].contains name
        mascot = Mascots[name]
        mascotEl = $.el 'div',
          className: 'mascot'
          id: name
          innerHTML: "
<div class='mascotname'>#{name.replace /_/g, " "}</span>
<div class='container #{mascot.category}'><img class=mascotimg src='#{if Array.isArray(mascot.image) then (if Style.lightTheme then mascot.image[1] else mascot.image[0]) else mascot.image}'></div>
"

        $.on mascotEl, 'click', cb.restore

        nodes.push mascotEl

      $.add categories, nodes

      $.add suboptions, categories

      batchmascots = $.el 'div',
        id: "mascots_batch"
        innerHTML: "<a href=\"javascript:;\" id=\"return\">Return</a>"

      $.on $('#return', batchmascots), 'click', ->
        mascots =
          open:            Settings.mascots
          hyphenatedTitle: 'mascots'
        Settings.openSection.apply mascots

    for node in [suboptions, batchmascots, mascotHide]
      Rice.nodes node

    $.add section, [suboptions, batchmascots, mascotHide]

  cb:
    mascot:
      category: ->
        if $.id(@name).hidden = @checked
          Conf["Hidden Categories"].push @name

          # Gather all names of enabled mascots in the hidden category in every context it could be enabled.
          for type in ["Enabled Mascots", "Enabled Mascots sfw", "Enabled Mascots nsfw"]
            setting = Conf[type]
            i = setting.length

            test = type is g.MASCOTSTRING

            while i--
              name = setting[i]
              continue unless Mascots[name].category is @name
              setting.remove name
              continue unless test
              $.rmClass $.id(name), 'enabled'
            $.set type, setting

        else
          Conf["Hidden Categories"].remove @name

        $.set "Hidden Categories", Conf["Hidden Categories"]

      edit: (e) ->
        e.stopPropagation()
        MascotTools.dialog @name
        Settings.close()

      delete: (e) ->
        e.stopPropagation()
        if confirm "Are you sure you want to delete \"#{@name}\"?"
          if Conf['mascot'] is @name
            MascotTools.init()
          for type in ["Enabled Mascots", "Enabled Mascots sfw", "Enabled Mascots nsfw"]
            Conf[type].remove @name
            $.set type, Conf[type]
          Conf["Deleted Mascots"].push @name
          $.set "Deleted Mascots", Conf["Deleted Mascots"]
          $.rm $.id @name

      export: (e) ->
        e.stopPropagation()
        exportMascot = Mascots[@name]
        exportMascot['Mascot'] = @name
        exportedMascot = "data:application/json," + encodeURIComponent(JSON.stringify(exportMascot))

        if window.open exportedMascot, "_blank"
          return
        else if confirm "Your popup blocker is preventing Appchan X from exporting this theme. Would you like to open the exported theme in this window?"
          window.location exportedMascot

      restore: ->
        if confirm "Are you sure you want to restore \"#{@id}\"?"
          Conf["Deleted Mascots"].remove @id
          $.set "Deleted Mascots", Conf["Deleted Mascots"]
          $.rm @

      select: ->
        if Conf[g.MASCOTSTRING].remove @id
          if Conf['mascot'] is @id
            MascotTools.init()
        else
          Conf[g.MASCOTSTRING].push @id
          MascotTools.init @id
        $.toggleClass @, 'enabled'
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING]


    theme:
      select: ->
        if currentTheme = $.id(Conf['theme'])
          $.rmClass currentTheme, 'selectedtheme'

        if Conf["NSFW/SFW Themes"]
          $.set "theme_#{g.TYPE}", @id
        else
          $.set "theme", @id
        Conf['theme'] = @id
        $.addClass @, 'selectedtheme'
        Style.addStyle()

      edit: (e) ->
        e.preventDefault()
        e.stopPropagation()
        ThemeTools.init @name
        Settings.close()

      export: (e) ->
        e.preventDefault()
        e.stopPropagation()
        exportTheme = Themes[@name]
        exportTheme['Theme'] = @name
        exportedTheme = "data:application/json," + encodeURIComponent(JSON.stringify(exportTheme))

        if window.open exportedTheme, "_blank"
          return
        else if confirm "Your popup blocker is preventing Appchan X from exporting this theme. Would you like to open the exported theme in this window?"
          window.location exportedTheme

      delete: (e) ->
        e.preventDefault()
        e.stopPropagation()
        container = $.id @name

        unless container.previousSibling or container.nextSibling
          alert "Cannot delete theme (No other themes available)."
          return

        if confirm "Are you sure you want to delete \"#{@name}\"?"
          if @name is Conf['theme']
            if settheme = container.previousSibling or container.nextSibling
              Conf['theme'] = settheme.id
              $.addClass settheme, 'selectedtheme'
              $.set 'theme', Conf['theme']
          Themes[@name]["Deleted"] = true

          $.get "userThemes", {}, ({userThemes}) =>
            userThemes[@name] = Themes[@name]
            $.set 'userThemes', userThemes
            $.rm container

      restore: ->
        if confirm "Are you sure you want to restore \"#{@id}\"?"
          Themes[@id]["Deleted"] = false

          $.get "userThemes", {}, ({userThemes}) =>
            userThemes[@id] = Themes[@id]
            $.set 'userThemes', userThemes
            $.rm @
