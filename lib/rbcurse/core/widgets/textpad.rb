#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: textpad.rb
#  Description: A class that displays text using a pad.
#         The motivation for this is to put formatted text and not care about truncating and 
#         stuff. Also, there will be only one write, not each time scrolling happens.
#         I found textview code for repaint being more complex than required.
#       Author: rkumar http://github.com/rkumar/mancurses/
#         Date: 2011-11-09 - 16:59
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-03-29 18:59
#
#  == CHANGES
#  == TODO 
#  Take care of 3 cases:
#     1. complete data change, then recreate pad, and call init_vars resetting row, col and curpos etc
#        This is done by method text().
#     2. row added or minor change - recreate pad, repaint data but don't call initvars. must maintain cursor
#        ignore recreate of pad if width or ht is less than w and h of container.
#     3. only rewrite a row - row data changed, no recreate pad or anything else
#
#
#
# ----------------------------------------------------------------------------- #
#
require 'rbcurse'
require 'rbcurse/core/include/bordertitle'

include RubyCurses
module RubyCurses
  extend self
  class TextPad < Widget
    include BorderTitle

    dsl_accessor :suppress_borders
    dsl_accessor :print_footer
    attr_reader :current_index
    attr_reader :rows , :cols
    # adding these only for debugging table, to see where cursor is.
    attr_reader :lastrow, :lastcol
    # for external methods or classes to advance cursor
    #attr_accessor :curpos
    # You may pass height, width, row and col for creating a window otherwise a fullscreen window
    # will be created. If you pass a window from caller then that window will be used.
    # Some keys are trapped, jkhl space, pgup, pgdown, end, home, t b
    # This is currently very minimal and was created to get me started to integrating
    # pads into other classes such as textview.
    def initialize form=nil, config={}, &block

      @editable = false
      @focusable = true
      @config = config
      @row = @col = 0
      @prow = @pcol = 0
      @startrow = 0
      @startcol = 0
      # @list is unused, think it can be removed
      @list = []
      super

      ## NOTE 
      #  ---------------------------------------------------
      #  Since we are using pads, you need to get your height, width and rows correct
      #  Make sure the height factors in the row, else nothing may show
      #  ---------------------------------------------------
      #@height = @height.ifzero(FFI::NCurses.LINES)
      #@width = @width.ifzero(FFI::NCurses.COLS)
      @rows = @height
      @cols = @width
      # NOTE XXX if cols is > COLS then padrefresh can fail
      @startrow = @row
      @startcol = @col
      unless @suppress_borders
        @row_offset = @col_offset = 1
        @startrow += 1
        @startcol += 1
        @rows -=3  # 3 is since print_border_only reduces one from width, to check whether this is correct
        @cols -=3
        @scrollatrows = @height - 3
      else
        # no borders printed
        @rows -= 1  # 3 is since print_border_only reduces one from width, to check whether this is correct
        ## if next is 0 then padrefresh doesn't print
        @cols -=1
        @scrollatrows = @height - 1 # check this out 0 or 1
        @row_offset = @col_offset = 0 
      end
      @top = @row
      @left = @col
      @lastrow = @row + @row_offset
      @lastcol = @col + @col_offset
      @_events << :PRESS
      @_events << :ENTER_ROW
      init_vars
    end
    def init_vars
      $multiplier = 0
      @oldindex = @current_index = 0
      # column cursor
      @prow = @pcol = @curpos = 0
      if @row && @col
        @lastrow = @row + @row_offset
        @lastcol = @col + @col_offset
      end
      @repaint_required = true
      map_keys unless @mapped_keys
    end
    def rowcol #:nodoc:
      return @row+@row_offset, @col+@col_offset
    end

    private
    ## XXX in list text returns the selected row, list returns the full thing, keep consistent
    def create_pad
      destroy if @pad
      #@pad = FFI::NCurses.newpad(@content_rows, @content_cols)
      @pad = @window.get_pad(@content_rows, @content_cols )
    end

    private
    # create and populate pad
    def populate_pad
      @_populate_needed = false
      @content_rows = @content.count
      @content_cols = content_cols()
      @content_rows = @rows if @content_rows < @rows
      @content_cols = @cols if @content_cols < @cols

      create_pad

      # clearstring is the string required to clear the pad to background color
      @clearstring = nil
      cp = get_color($datacolor, @color, @bgcolor)
      @cp = FFI::NCurses.COLOR_PAIR(cp)
      if cp != $datacolor
        @clearstring ||= " " * @width
      end

      Ncurses::Panel.update_panels
      render_all

    end
    #
    # iterate through content rendering each row
    # 2013-03-27 - 01:51 separated so that widgets with headers such as tables can
    # override this for better control
    def render_all
      @content.each_index { |ix|
        #FFI::NCurses.mvwaddstr(@pad,ix, 0, @content[ix])
        render @pad, ix, @content[ix]
      }
    end

    public
    # supply a custom renderer that implements +render()+
    # @see render
    def renderer r
      @renderer = r
    end
    #
    # default method for rendering a line
    #
    def render pad, lineno, text
      if text.is_a? Chunks::ChunkLine
        FFI::NCurses.wmove @pad, lineno, 0
        a = get_attrib @attrib
      
        show_colored_chunks text, nil, a
        return
      end
      if @renderer
        @renderer.render @pad, lineno, text
      else
        ## messabox does have a method to paint the whole window in bg color its in rwidget.rb
        att = NORMAL
        FFI::NCurses.wattron(@pad, @cp | att)
        FFI::NCurses.mvwaddstr(@pad,lineno, 0, @clearstring) if @clearstring
        FFI::NCurses.mvwaddstr(@pad,lineno, 0, @content[lineno])

        #FFI::NCurses.mvwaddstr(pad, lineno, 0, text)
        FFI::NCurses.wattroff(@pad, @cp | att)
      end
    end

    # supply a filename as source for textpad
    # Reads up file into @content
    # One can optionally send in a method which takes a filename and returns an array of data
    # This is required if you are processing files which are binary such as zip/archives and wish
    # to print the contents. (e.g. cygnus gem sends in :get_file_contents).
    #      filename("a.c", method(:get_file_contents))
    #
    def filename(filename, reader=nil)
      @file = filename
      unless File.exists? filename
        alert "#{filename} does not exist"
        return
      end
      @filetype = File.extname filename
      if reader
        @content = reader.call(filename)
      else
        @content = File.open(filename,"r").readlines
      end
      if @filetype == ""
        if @content.first.index("ruby")
          @filetype = ".rb"
        end
      end
      init_vars
      @repaint_all = true
      @_populate_needed = true
    end

    # Supply an array of string to be displayed
    # This will replace existing text

    # display text given in an array format. This is the principal way of giving content
    # to a textpad, other than filename().
    # @param Array of lines
    # @param format (optional) can be :tmux :ansi or :none
    # If a format other than :none is given, then formatted_text is called.
    def text(lines, fmt=:none)
      # added so callers can have one interface and avoid an if condition
      return formatted_text(lines, fmt) unless fmt == :none

      return @content if lines.empty?
      @content = lines
      @_populate_needed = true
      @repaint_all = true
      init_vars
      self
    end
    alias :list :text
    # for compat with textview
    alias :set_content :text
    def content
      raise "content is nil " unless @content
      return @content
    end
    alias :get_content :content

    # print footer containing line and position
    # XXX UNTESTED TODO TESTING
    def print_foot #:nodoc:
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos+@pcol}, #{@list.length} lines  "
      $log.debug " print_foot calling printstring with #{@row} + #{@height} -1, #{@col}+2"
      @graphic.printstring( @row + @height -1 , @col+2, footer, @color_pair || $datacolor, @footer_attrib) 
      @repaint_footer_required = false # 2010-01-23 22:55 
    end

    ## ---- the next 2 methods deal with printing chunks
    # we should put it int a common module and include it
    # in Window and Pad stuff and perhaps include it conditionally.

    ## 2013-03-07 - 19:57 changed width to @content_cols since data not printing
    # in some cases fully when ansi sequences were present int some line but not in others
    # lines without ansi were printing less by a few chars.
    # This was prolly copied from rwindow, where it is okay since its for a specific width
    def print(string, _width = @content_cols)
      #return unless visible?
      w = _width == 0? Ncurses.COLS : _width
      FFI::NCurses.waddnstr(@pad,string.to_s, w) # changed 2011 dts  
    end

    def show_colored_chunks(chunks, defcolor = nil, defattr = nil)
      #return unless visible?
      chunks.each do |chunk| #|color, chunk, attrib|
        case chunk
        when Chunks::Chunk
          color = chunk.color
          attrib = chunk.attrib
          text = chunk.text
        when Array
          # for earlier demos that used an array
          color = chunk[0]
          attrib = chunk[2]
          text = chunk[1]
        end

        color ||= defcolor
        attrib ||= defattr || NORMAL

        #cc, bg = ColorMap.get_colors_for_pair color
        #$log.debug "XXX: CHUNK textpad #{text}, cp #{color} ,  attrib #{attrib}. #{cc}, #{bg} "
        FFI::NCurses.wcolor_set(@pad, color,nil) if color
        FFI::NCurses.wattron(@pad, attrib) if attrib
        print(text)
        FFI::NCurses.wattroff(@pad, attrib) if attrib
      end
    end

    # 
    # pass in formatted text along with parser (:tmux or :ansi)
    # NOTE this does not call init_vars, i think it should, text() does
    def formatted_text text, fmt

      require 'rbcurse/core/include/chunk'
      @formatted_text = text
      @color_parser = fmt
      @repaint_required = true
      # don't know if start is always required. so putting in caller
      #goto_start
      #remove_all
    end

    # write pad onto window
    #private
    def padrefresh
      top = @window.top
      left = @window.left
      sr = @startrow + top
      sc = @startcol + left
      retval = FFI::NCurses.prefresh(@pad,@prow,@pcol, sr , sc , @rows + sr , @cols+ sc );
      $log.warn "XXX:  PADREFRESH #{retval}, #{@prow}, #{@pcol}, #{sr}, #{sc}, #{@rows+sr}, #{@cols+sc}." if retval == -1
      # padrefresh can fail if width is greater than NCurses.COLS
      #FFI::NCurses.prefresh(@pad,@prow,@pcol, @startrow + top, @startcol + left, @rows + @startrow + top, @cols+@startcol + left);
    end

    # convenience method to return byte
    private
    def key x
      x.getbyte(0)
    end

    # length of longest string in array
    # This will give a 'wrong' max length if the array has ansi color escape sequences in it
    # which inc the length but won't be printed. Such lines actually have less length when printed
    # So in such cases, give more space to the pad.
    def content_cols
      longest = @content.max_by(&:length)
      ## 2013-03-06 - 20:41 crashes here for some reason when man gives error message no man entry
      return 0 unless longest
      longest.length
    end

    public
    # to be called with program / user has added a row or changed column widths so that 
    # the pad needs to be recreated. However, cursor positioning is maintained since this
    # is considered to be a minor change. 
    # We do not call init_vars since user is continuing to do some work on a row/col.
    def fire_dimension_changed
      # recreate pad since width or ht has changed (row count or col width changed)
      @_populate_needed = true
      @repaint_required = true
      @repaint_all = true
    end
    # repaint only one row since content of that row has changed. 
    # No recreate of pad is done.
    def fire_row_changed ix
      render @pad, ix, @content[ix]
      # may need to call padrefresh TODO TESTING
    end
    def repaint
      ## 2013-03-08 - 21:01 This is the fix to the issue of form callign an event like ? or F1
      # which throws up a messagebox which leaves a black rect. We have no place to put a refresh
      # However, form does call repaint for all objects, so we can do a padref here. Otherwise,
      # it would get rejected. UNfortunately this may happen more often we want, but we never know
      # when something pops up on the screen.
      unless @repaint_required
        padrefresh 
        return 
      end
      if @formatted_text
        #$log.debug "XXX:  INSIDE FORMATTED TEXT "

        l = RubyCurses::Utils.parse_formatted_text(@color_parser,
                                               @formatted_text)

        text(l)
        @formatted_text = nil
      end

      ## moved this line up or else create_p was crashing
      @window ||= @graphic
      populate_pad if @_populate_needed
      #HERE we need to populate once so user can pass a renderer
      unless @suppress_borders
        if @repaint_all
          ## XXX im not getting the background color.
          #@window.print_border_only @top, @left, @height-1, @width, $datacolor
          clr = get_color $datacolor, @color, @bgcolor
          #@window.print_border @top, @left, @height-1, @width, clr
          @window.print_border_only @top, @left, @height-1, @width, clr
          print_title

          @repaint_footer_required = true if @oldrow != @current_index 
          print_foot if @print_footer && !@suppress_borders && @repaint_footer_required

          @window.wrefresh
        end
      end

      padrefresh
      Ncurses::Panel.update_panels
      @repaint_required = false
      @repaint_all = false
    end

    #
    # key mappings
    #
    def map_keys
      @mapped_keys = true
      bind_key([?g,?g], 'goto_start'){ goto_start } # mapping double keys like vim
      bind_key(279, 'goto_start'){ goto_start } 
      bind_keys([?G,277], 'goto end'){ goto_end } 
      bind_keys([?k,KEY_UP], "Up"){ up } 
      bind_keys([?j,KEY_DOWN], "Down"){ down } 
      bind_key(?\C-e, "Scroll Window Down"){ scroll_window_down } 
      bind_key(?\C-y, "Scroll Window Up"){ scroll_window_up } 
      bind_keys([32,338, ?\C-d], "Scroll Forward"){ scroll_forward } 
      bind_keys([?\C-b,339]){ scroll_backward } 
      # the next one invalidates the single-quote binding for bookmarks
      #bind_key([?',?']){ goto_last_position } # vim , goto last row position (not column)
      bind_key(?/, :ask_search)
      bind_key(?n, :find_more)
      bind_key([?\C-x, ?>], :scroll_right)
      bind_key([?\C-x, ?<], :scroll_left)
      bind_key(?\M-l, :scroll_right)
      bind_key(?\M-h, :scroll_left)
      bind_key(?L, :bottom_of_window)
      bind_key(?M, :middle_of_window)
      bind_key(?H, :top_of_window)
      bind_key(?w, :forward_word)
      bind_key(?b, :backward_word)
      bind_key(?l, :cursor_forward)
      bind_key(?h, :cursor_backward)
      bind_key(?$, :cursor_eol)
      bind_key(KEY_ENTER, :fire_action_event)
    end

    # goto first line of file
    def goto_start
      #@oldindex = @current_index
      $multiplier ||= 0
      if $multiplier > 0
        goto_line $multiplier - 1
        return
      end
      @current_index = 0
      @curpos = @pcol = @prow = 0
      @prow = 0
      $multiplier = 0
    end

    # goto last line of file
    def goto_end
      #@oldindex = @current_index
      $multiplier ||= 0
      if $multiplier > 0
        goto_line $multiplier - 1
        return
      end
      @current_index = @content.count() - 1
      @prow = @current_index - @scrollatrows
      $multiplier = 0
    end
    def goto_line line
      ## we may need to calculate page, zfm style and place at right position for ensure visible
      #line -= 1
      @current_index = line
      ensure_visible line
      bounds_check
      $multiplier = 0
    end
    def top_of_window
      @current_index = @prow 
      $multiplier ||= 0
      if $multiplier > 0
        @current_index += $multiplier
        $multiplier = 0
      end
    end
    def bottom_of_window
      @current_index = @prow + @scrollatrows
      $multiplier ||= 0
      if $multiplier > 0
        @current_index -= $multiplier
        $multiplier = 0
      end
    end
    def middle_of_window
      @current_index = @prow + (@scrollatrows/2)
      $multiplier = 0
    end

    # move down a line mimicking vim's j key
    # @param [int] multiplier entered prior to invoking key
    def down num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      #@oldindex = @current_index if num > 10
      @current_index += num
      # no , i don't like this here. it scrolls up too much making prow = current_index
      unless is_visible? @current_index
          @prow += num
      end
      #ensure_visible
      $multiplier = 0
    end

    # move up a line mimicking vim's k key
    # @param [int] multiplier entered prior to invoking key
    def up num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      #@oldindex = @current_index if num > 10
      @current_index -= num
      #unless is_visible? @current_index
        #if @prow > @current_index
          ##$status_message.value = "1 #{@prow} > #{@current_index} "
          #@prow -= 1
        #else
        #end
      #end
      $multiplier = 0
    end

    # scrolls window down mimicking vim C-e
    # @param [int] multiplier entered prior to invoking key
    def scroll_window_down num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @prow += num
        if @prow > @current_index
          @current_index += 1
        end
      #check_prow
      $multiplier = 0
    end

    # scrolls window up mimicking vim C-y
    # @param [int] multiplier entered prior to invoking key
    def scroll_window_up num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @prow -= num
      unless is_visible? @current_index
        # one more check may be needed here TODO
        @current_index -= num
      end
      $multiplier = 0
    end

    # scrolls lines a window full at a time, on pressing ENTER or C-d or pagedown
    def scroll_forward
      #@oldindex = @current_index
      @current_index += @scrollatrows
      @prow = @current_index - @scrollatrows
    end

    # scrolls lines backward a window full at a time, on pressing pageup 
    # C-u may not work since it is trapped by form earlier. Need to fix
    def scroll_backward
      #@oldindex = @current_index
      @current_index -= @scrollatrows
      @prow = @current_index - @scrollatrows
    end
    def goto_last_position
      return unless @oldindex
      tmp = @current_index
      @current_index = @oldindex
      @oldindex = tmp
      bounds_check
    end
    def scroll_right
      # I don't think it will ever be less since we've increased it to cols
      if @content_cols <= @cols
        maxpcol = 0
        @pcol = 0
      else
        maxpcol = @content_cols - @cols - 1
        @pcol += 1
        @pcol = maxpcol if @pcol > maxpcol
      end
      # to prevent right from retaining earlier painted values
      # padreader does not do a clear, yet works fine.
      # OK it has an update_panel after padrefresh, that clears it seems.
      #this clears entire window not just the pad
      #FFI::NCurses.wclear(@window.get_window)
      # so border and title is repainted after window clearing
      #
      # Next line was causing all sorts of problems when scrolling  with ansi formatted text
      #@repaint_all = true
    end
    def scroll_left
      @pcol -= 1
    end
    #
    #
    #
    #
    def handle_key ch
      return :UNHANDLED unless @content


      @oldrow = @prow
      @oldcol = @pcol
      $log.debug "XXX: PAD got #{ch} prow = #{@prow}"
      begin
        case ch
      when ?0.getbyte(0)..?9.getbyte(0)
        if ch == ?0.getbyte(0) && $multiplier == 0
          cursor_bol
          return 0
        end
        # storing digits entered so we can multiply motion actions
        $multiplier *= 10 ; $multiplier += (ch-48)
        return 0
        when ?\C-c.getbyte(0)
          $multiplier = 0
          return 0
        else
          # check for bindings, these cannot override above keys since placed at end
          begin
            ret = process_key ch, self
            $multiplier = 0
            bounds_check
            ## If i press C-x > i get an alert from rwidgets which blacks the screen
            # if i put a padrefresh here it becomes okay but only for one pad,
            # i still need to do it for all pads.
          rescue => err
            $log.error " TEXTPAD ERROR INS #{err} "
            $log.debug(err.backtrace.join("\n"))
            textdialog ["Error in TextPad: #{err} ", *err.backtrace], :title => "Exception"
          end
          ## NOTE if textpad does not handle the event and it goes to form which pops
          # up a messagebox, then padrefresh does not happen, since control does not 
          # come back here, so a black rect is left on screen
          # please note that a bounds check will not happen for stuff that 
          # is triggered by form, so you'll have to to it yourself or 
          # call setrowcol explicity if the cursor is not updated
          return :UNHANDLED if ret == :UNHANDLED
        end
      rescue => err
        $log.error " TEXTPAD ERROR 591 #{err} "
        $log.debug( err) if err
        $log.debug(err.backtrace.join("\n")) if err
        textdialog ["Error in TextPad: #{err} ", *err.backtrace], :title => "Exception"
        $error_message.value = ""
      ensure
        padrefresh
        Ncurses::Panel.update_panels
      end
      return 0
    end # while loop

    #
    # event when user hits enter on a row, user would bind :PRESS
    #
    def fire_action_event
      return if @content.nil? || @content.size == 0
      require 'rbcurse/core/include/ractionevent'
      aev = TextActionEvent.new self, :PRESS, current_value().to_s, @current_index, @curpos
      fire_handler :PRESS, aev
    end
    #
    # returns current value (what cursor is on)
    def current_value
      @content[@current_index]
    end
    # 
    # execute binding when a row is entered, used more in lists to display some text
    # in a header or footer as one traverses
    #
    def on_enter_row arow
      return if @content.nil? || @content.size == 0
      require 'rbcurse/core/include/ractionevent'
      aev = TextActionEvent.new self, :ENTER_ROW, current_value().to_s, @current_index, @curpos
      fire_handler :ENTER_ROW, aev
      @repaint_required = true
    end

    # destroy the pad, this needs to be called from somewhere, like when the app
    # closes or the current window closes , or else we could have a seg fault
    # or some ugliness on the screen below this one (if nested).

    # Now since we use get_pad from window, upon the window being destroyed,
    # it will call this. Else it will destroy pad
    def destroy
      FFI::NCurses.delwin(@pad) if @pad # when do i do this ? FIXME
      @pad = nil
    end
    # 
    # return true if the given row is visible
    def is_visible? index
      j = index - @prow #@toprow
      j >= 0 && j <= @scrollatrows
    end
    #
    # called when this widget is entered, by form
    def on_enter
      set_form_row
    end
    # called by form
    def set_form_row
      setrowcol @lastrow, @lastcol
    end
    # called by form
    def set_form_col
    end

    private
    
    # check that current_index and prow are within correct ranges
    # sets row (and someday col too)
    # sets repaint_required

    def bounds_check
      r,c = rowcol
      @current_index = 0 if @current_index < 0
      @current_index = @content.count()-1 if @current_index > @content.count()-1
      ensure_visible

      check_prow
      #$log.debug "XXX: PAD BOUNDS ci:#{@current_index} , old #{@oldrow},pr #{@prow}, max #{@maxrow} pcol #{@pcol} maxcol #{@maxcol}"
      @crow = @current_index + r - @prow
      @crow = r if @crow < r
      # 2 depends on whetehr suppressborders
      if @suppress_borders
        @crow = @row + @height -1 if @crow >= r + @height -1
      else
        @crow = @row + @height -2 if @crow >= r + @height -2
      end
      setrowcol @crow, @curpos+c
      lastcurpos @crow, @curpos+c
      if @oldindex != @current_index
        on_enter_row @current_index
        @oldindex = @current_index
      end
      if @oldrow != @prow || @oldcol != @pcol
        # only if scrolling has happened.
        @repaint_required = true
      end
    end
    # 
    # save last cursor position so when reentering, cursor can be repositioned
    def lastcurpos r,c
      @lastrow = r
      @lastcol = c
    end


    # check that prow and pcol are within bounds
    #
    def check_prow
      @prow = 0 if @prow < 0
      @pcol = 0 if @pcol < 0

      cc = @content.count

      if cc < @rows
        @prow = 0
      else
        maxrow = cc - @rows - 1
        if @prow > maxrow
          @prow = maxrow
        end
      end
      # we still need to check the max that prow can go otherwise
      # the pad shows earlier stuff.
      # 
      return
    end
    public
    ## 
    # Ask user for string to search for
    # This uses the dialog, but what if user wants the old style.
    # Isn't there a cleaner way to let user override style, or allow user
    # to use own UI for getting pattern and then passing here.
    # @param str default nil. If not passed, then user is prompted using get_string dialog
    #    This allows caller to use own method to prompt for string such as 'get_line' or 'rbgetstr' /
    #    'ask()'
    def ask_search str=nil
      # the following is a change that enables callers to prompt for the string
      # using some other style, basically the classical style and send the string in
      str = get_string("Enter pattern: ") unless str
      return if str.nil? 
      str = @last_regex if str == ""
      return if str == ""
      ix = next_match str
      return unless ix
      @last_regex = str

      #@oldindex = @current_index
      @current_index = ix[0]
      @curpos = ix[1]
      ensure_visible
    end
    ## 
    # Find next matching row for string accepted in ask_search
    #
    def find_more
      return unless @last_regex
      ix = next_match @last_regex
      return unless ix
      #@oldindex = @current_index
      @current_index = ix[0]
      @curpos = ix[1]
      ensure_visible
    end

    ## 
    # Find the next row that contains given string
    # @return row and col offset of match, or nil
    # @param String to find
    def next_match str
      first = nil
      ## content can be string or Chunkline, so we had to write <tt>index</tt> for this.
      ## =~ does not give an error, but it does not work.
      @content.each_with_index do |line, ix|
        col = line.index str
        if col
          first ||= [ ix, col ]
          if ix > @current_index
            return [ix, col]
          end
        end
      end
      return first
    end
    ## 
    # Ensure current row is visible, if not make it first row
    # NOTE - need to check if its at end and then reduce scroll at rows, check_prow does that
    # 
    # @param current_index (default if not given)
    #
    def ensure_visible row = @current_index
      unless is_visible? row
          @prow = @current_index
      end
    end
    #
    # jumps cursor to next work, like vim's w key
    #
    def forward_word
      $multiplier = 1 if !$multiplier || $multiplier == 0
      line = @current_index
      buff = @content[line].to_s
      return unless buff
      pos = @curpos || 0 # list does not have curpos
      $multiplier.times {
        found = buff.index(/[[:punct:][:space:]]\w/, pos)
        if !found
          # if not found, we've lost a counter
          if line+1 < @content.length
            line += 1
          else
            return
          end
          pos = 0
        else
          pos = found + 1
        end
        $log.debug " forward_word: pos #{pos} line #{line} buff: #{buff}"
      }
      $multiplier = 0
      @current_index = line
      @curpos = pos
      ensure_visible
      @repaint_required = true
    end
    def backward_word
      $multiplier = 1 if !$multiplier || $multiplier == 0
      line = @current_index
      buff = @content[line].to_s
      return unless buff
      pos = @curpos || 0 # list does not have curpos
      $multiplier.times {
        found = buff.rindex(/[[:punct:][:space:]]\w/, pos-2)
        if !found || found == 0
          # if not found, we've lost a counter
          if pos > 0
            pos = 0
          elsif line > 0
            line -= 1
            pos = @content[line].to_s.size
          else
            return
          end
        else
          pos = found + 1
        end
        $log.debug " backward_word: pos #{pos} line #{line} buff: #{buff}"
      }
      $multiplier = 0
      @current_index = line
      @curpos = pos
      ensure_visible
      @repaint_required = true
    end
    #
    # move cursor forward by one char (currently will not pan)
    def cursor_forward
      $multiplier = 1 if $multiplier == 0
      if @curpos < @cols
        @curpos += $multiplier
        if @curpos > @cols
          @curpos = @cols
        end
        @repaint_required = true
      end
      $multiplier = 0
    end
    #
    # move cursor backward by one char (currently will not pan)
    def cursor_backward
      $multiplier = 1 if $multiplier == 0
      if @curpos > 0
        @curpos -= $multiplier
        @curpos = 0 if @curpos < 0
        @repaint_required = true
      end
      $multiplier = 0
    end
    # moves cursor to end of line also panning window if necessary
    # NOTE: if one line on another page (not displayed) is way longer than any
    # displayed line, then this will pan way ahead, so may not be very intelligent
    # in such situations.
    def cursor_eol
      # pcol is based on max length not current line's length
      @pcol = @content_cols - @cols - 1
      @curpos = @content[@current_index].size
      @repaint_required = true
    end
    # 
    # moves cursor to start of line, panning if required
    def cursor_bol
      # copy of C-a - start of line
      @repaint_required = true if @pcol > 0
      @pcol = 0
      @curpos = 0
    end

  end  # class textpad

  # a test renderer to see how things go
  class DefaultFileRenderer
    #
    # @param pad for calling print methods on
    # @param lineno the line number on the pad to print on
    # @param text data to print
    def render pad, lineno, text
      bg = :black
      fg = :white
      att = NORMAL
      #cp = $datacolor
      cp = get_color($datacolor, fg, bg)
      ## XXX believe it or not, the next line can give you "invalid byte sequence in UTF-8
      # even when processing filename at times. Or if its an mp3 or non-text file.
      if text =~ /^\s*# / || text =~ /^\s*## /
        fg = :red
        #att = BOLD
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*#/
        fg = :blue
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*(class|module) /
        fg = :cyan
        att = BOLD
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*def / || text =~ /^\s*function /
        fg = :yellow
        att = BOLD
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*(end|if |elsif|else|begin|rescue|ensure|include|extend|while|unless|case |when )/
        fg = :magenta
        att = BOLD
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*=/
        # rdoc case
        fg = :blue
        bg = :white
        cp = get_color($datacolor, fg, bg)
        att = REVERSE
      end
      FFI::NCurses.wattron(pad,FFI::NCurses.COLOR_PAIR(cp) | att)
      FFI::NCurses.mvwaddstr(pad, lineno, 0, text)
      FFI::NCurses.wattroff(pad,FFI::NCurses.COLOR_PAIR(cp) | att)

    end
  end
end
