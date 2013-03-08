=begin
  * Name: TextView 
  * Description   View text in this widget.
  * Author: rkumar (arunachalesha)
  * file created 2009-01-08 15:23  
  * major change: 2010-02-10 19:43 simplifying the buffer stuff.
TODO 
   * border, and footer could be objects (classes) at some future stage.
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'logger'
require 'rbcurse'
require 'rbcurse/core/include/listscrollable'
require 'rbcurse/core/include/bordertitle'
require 'forwardable'

include RubyCurses
module RubyCurses
  extend self

  ##
  # A viewable read only box. Can scroll. 
  # Intention is to be able to change content dynamically - the entire list.
  # Use set_content to set content, or just update the list attrib
  # TODO - 
  #      - goto line - DONE
  class TextView < Widget
    include ListScrollable
    extend Forwardable
    #dsl_accessor :height  # height of viewport cmmented on 2010-01-09 19:29 since widget has method
    #dsl_accessor :title   # set this on top
    #dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :footer_attrib   # bold, reverse, normal
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # max len to be displayed
    attr_reader :toprow    # the toprow in the view (offsets are 0)
    # painting the footer does slow down cursor painting slightly if one is moving cursor fast
    dsl_accessor :print_footer
    attr_reader :current_index
    dsl_accessor :sanitization_required

    def initialize form = nil, config={}, &block
      @focusable = true
      @editable = false
      @sanitization_required = true
      @suppress_borders = false
      @row_offset = @col_offset = 1 
      @row = 0
      @col = 0
      @show_focus = false  # don't highlight row under focus
      @list = []
      map_keys
      super
      # ideally this should have been 2 to take care of borders, but that would break
      # too much stuff !
      @win = @graphic

      @_events.push :CHANGE # thru vieditable
      @_events << :PRESS # new, in case we want to use this for lists and allow ENTER
      @_events << :ENTER_ROW # new, should be there in listscrollable ??
      install_keys # do something about this nonsense FIXME
      bordertitle_init
      init_vars
      init_actions
    end
    def init_vars #:nodoc:
      @curpos = @pcol = @toprow = @current_index = 0
      @repaint_all=true 
      @repaint_required=true 
      @widget_scrolled = true
      ## 2010-02-10 20:20 RFED16 taking care if no border requested
      @row_offset = @col_offset = 0 if @suppress_borders == true
      # added 2010-02-11 15:11 RFED16 so we don't need a form.
      $error_message_row ||= 23
      $error_message_col ||= 1
      # currently i scroll right only if  current line is longer than display width, i should use 
      # longest line on screen.
      @longest_line = 0 # the longest line printed on this page, used to determine if scrolling shd work
      @internal_width = 2
      @internal_width = 0 if @suppress_borders # NOTE bordertitle says 1

      @search_found_ix = nil # so old searches don't get highlighted
    end
    def map_keys
      require 'rbcurse/core/include/listbindings'
      bindings()
      #bind_key([?\C-x, ?\C-s], :saveas)
      #bind_key([?\C-x, ?e], :edit_external)
      bind_key(32, 'scroll forward'){ scroll_forward() }
      # have placedhere so multi-bufer can override BS to prev buffer
      bind_keys([KEY_BACKSPACE,KEY_BSPACE,KEY_DELETE], :cursor_backward)
      #bind_key(?r) { getstr("Enter a word: ") } if $log.debug?
      #bind_key(?m, :disp_menu)                  if $log.debug?
    end
    ## 
    # send in a list
    # e.g.         set_content File.open("README.txt","r").readlines
    # set wrap at time of passing :WRAP_NONE :WRAP_WORD
    # XXX if we widen the textview later, as in a vimsplit that data
    # will sti1ll be wrapped at this width !!
    #  2011-12-3 changed wrap to hash, so we can use content_type :ansi, :tmux
    def set_content list, config = {} #wrap = :WRAP_NONE
      @content_type = config[:content_type]
      _title = config[:title]
      self.title = _title if _title
      if @content_type
        formatted_text list, @content_type
        return
      end
      # please note that content type is lost once formatted text does it's work
      @wrap_policy = config[:wrap]
      if list.is_a? String
        if @wrap_policy == :WRAP_WORD
          data = wrap_text list
          @list = data.split("\n")
        else
          @list = list.split("\n")
        end
      elsif list.is_a? Array
        if @wrap_policy == :WRAP_WORD
          data = wrap_text list.join(" ")
          @list = data.split("\n")
        else
          @list = list
        end
      else
        raise "set_content expects Array not #{list.class}"
      end
      init_vars
    end
    # for consistency with other objects that respect text
    #alias :text :set_content
    def text(*val)
      if val.empty?
        return @list
      end
      set_content(*val)
      self
    end
    def text=(val)
      return unless val # added 2010-11-17 20:11, dup will fail on nil
      set_content(val)
    end
    def formatted_text text, fmt
      require 'rbcurse/core/include/chunk'
      @formatted_text = text
      @color_parser = fmt
      remove_all
    end
    #def <<(line); @list << line; @widget_scrolled = true;  end
    def_delegators :@list, :include?, :each, :values, :size
    %w[ insert clear delete_at []= << ].each { |e| 
      eval %{
      def #{e}(*args)
         @list.send(:#{e}, *args)
         @widget_scrolled = true
         @repaint_required = true
      end
      }
    }
    alias :append :<<

    def remove_all
      @list = []
      init_vars
      @repaint_required = true
    end
    ## display this row on top
    def top_row(*val) #:nodoc:
      if val.empty?
        @toprow
      else
        @toprow = val[0] || 0
      end
      @repaint_required = true
    end
    ## ---- for listscrollable ---- ##
    def scrollatrow #:nodoc:
      if @suppress_borders
        @height - 1  # should be 2 FIXME but erasing lower line. see appemail
      else
        @height - 3 
      end
    end
    def row_count
      @list.length
    end
    ##
    # returns row of first match of given regex (or nil if not found)
    def find_first_match regex #:nodoc:
      @list.each_with_index do |row, ix|
        return ix if !row.match(regex).nil?
      end
      return nil
    end
    ## returns the position where cursor was to be positioned by default
    # It may no longer work like that. 
    def rowcol #:nodoc:
      return @row+@row_offset, @col+@col_offset
    end
    def wrap_text(txt, col = @maxlen) #:nodoc:
      col ||= @width-@internal_width
      #$log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    def print_foot #:nodoc:
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos+@pcol}, #{@list.length} lines  "
      $log.debug " print_foot calling printstring with #{@row} + #{@height} -1, #{@col}+2"
      @graphic.printstring( @row + @height -1 , @col+2, footer, @color_pair || $datacolor, @footer_attrib) 
      @repaint_footer_required = false # 2010-01-23 22:55 
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window #:nodoc:
      @graphic
    end

    def repaint # textview :nodoc:
      #$log.debug "TEXTVIEW repaint r c #{@row}, #{@col}, key: #{$current_key}, reqd #{@repaint_required} "  

      #return unless @repaint_required # 2010-02-12 19:08  TRYING - won't let footer print for col move
      # TRYING OUT dangerous 2011-10-13 
      @repaint_required = false
      @repaint_required = true if @widget_scrolled || @pcol != @old_pcol || @record_changed || @property_changed

      paint if @repaint_required

      @repaint_footer_required = true if @oldrow != @current_index # 2011-10-15 
      print_foot if @print_footer && !@suppress_borders && @repaint_footer_required
    end
    # this sucks and should not be used but is everywhere, should
    # use text()
    def getvalue
      @list
    end
    def current_value
      @list[@current_index]
    end

    # determine length of row since we have chunks now.
    # Since chunk implements length, so not required except for the old
    # cases of demos that use an array.
    def row_length
      case @buffer
      when String
        @buffer.length
      when Chunks::ChunkLine
        return @buffer.length
      when Array
        # this is for those old cases like rfe.rb which sent in an array
        # (before we moved to chunks) 
        # line is an array of arrays
        if @buffer[0].is_a? Array
          result = 0
          @buffer.each {|e| result += e[1].length  }
          return result
        end
        # line is one single chunk
        return @buffer[1].length
      end
    end
    # textview
    # NOTE: i think this should return if list is nil or empty. No need to put
    #
    # stuff into buffer and continue. will trouble other classes that extend.
    def handle_key ch #:nodoc:
      $log.debug " textview got ch #{ch} "
      @old_pcol = @pcol
      @buffer = @list[@current_index]
      if @buffer.nil? && row_count == 0
        @list << "\r"
        @buffer = @list[@current_index]
      end
      return if @buffer.nil?
      #$log.debug " before: curpos #{@curpos} blen: #{row_length}"
      if @curpos > row_length #@buffer.length
        addcol((row_length-@curpos)+1)
        @curpos = row_length
        set_form_col 
      end
      # We can improve later
      case ch
      when KEY_UP, ?k.getbyte(0)
        #select_prev_row
        ret = up
        # next removed as very irritating, can be configured if required 2011-11-2 
        #get_window.ungetch(KEY_BTAB) if ret == :NO_PREVIOUS_ROW
        check_curpos
        
      when KEY_DOWN, ?j.getbyte(0)
        ret = down
        # This should be configurable, or only if all rows are visible
        #get_window.ungetch(KEY_TAB) if ret == :NO_NEXT_ROW
        check_curpos
      #when KEY_LEFT, ?h.getbyte(0)
        #cursor_backward
      #when KEY_RIGHT, ?l.getbyte(0)
        #cursor_forward
      when ?\C-a.getbyte(0) #, ?0.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at start
        @repaint_required = true if @pcol > 0 # tried other things but did not work
        set_form_col 0
        @pcol = 0
      when ?\C-e.getbyte(0), ?$.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at end
        # This use to actually pan the screen to actual end of line, but now somewhere
        # it only goes to end of visible screen, set_form probably does a sanity check
        blen = row_length # @buffer.rstrip.length FIXME
        set_form_col blen
      when KEY_ENTER, FFI::NCurses::KEY_ENTER
        #fire_handler :PRESS, self
        fire_action_event
      when ?0.getbyte(0)..?9.getbyte(0)
        # FIXME the assumption here was that if numbers are being entered then a 0 is a number
        # not a beg-of-line command.
        # However, after introducing universal_argument, we can enters numbers using C-u and then press another
        # C-u to stop. In that case a 0 should act as a command, even though multiplier has been set
        if ch == ?0.getbyte(0) and $multiplier == 0
          # copy of C-a - start of line
          @repaint_required = true if @pcol > 0 # tried other things but did not work
          set_form_col 0
          @pcol = 0
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
        rescue => err
          $log.error " TEXTVIEW ERROR #{err} "
          $log.debug(err.backtrace.join("\n"))
          textdialog [err.to_s, *err.backtrace], :title => "Exception"
        end
        return :UNHANDLED if ret == :UNHANDLED
      end
      $multiplier = 0 # you must reset if you've handled a key. if unhandled, don't reset since parent could use
      set_form_row
      return 0 # added 2010-01-12 22:17 else down arrow was going into next field
    end
    # newly added to check curpos when moving up or down
    def check_curpos #:nodoc:
      @buffer = @list[@current_index]
      # if the cursor is ahead of data in this row then move it back
      if @pcol+@curpos > row_length
        addcol((@pcol+row_length-@curpos)+1)
        @curpos = row_length 
        maxlen = (@maxlen || @width-@internal_width)

        # even this row is gt maxlen, i.e., scrolled right
        if @curpos > maxlen
          @pcol = @curpos - maxlen
          @curpos = maxlen-1 
        else
          # this row is within maxlen, make scroll 0
          @pcol=0
        end
        set_form_col 
      end
    end
    # set cursor on correct column tview
    def set_form_col col1=@curpos #:nodoc:
      @cols_panned ||= 0
      @pad_offset ||= 0 # added 2010-02-11 21:54 since padded widgets get an offset.
      @curpos = col1
      maxlen = @maxlen || @width-@internal_width
      #@curpos = maxlen if @curpos > maxlen
      if @curpos > maxlen
        @pcol = @curpos - maxlen
        @curpos = maxlen - 1
        @repaint_required = true # this is required so C-e can pan screen
      else
        @pcol = 0
      end
      # the rest only determines cursor placement
      win_col = 0 # 2010-02-07 23:19 new cursor stuff
      col2 = win_col + @col + @col_offset + @curpos + @cols_panned + @pad_offset
      $log.debug "TV SFC #{@name} setting c to #{col2} #{win_col} #{@col} #{@col_offset} #{@curpos} "
      #@form.setrowcol @form.row, col
      setrowcol nil, col2
      @repaint_footer_required = true
    end
    def cursor_forward #:nodoc:
      maxlen = @maxlen || @width-@internal_width
      repeatm { 
      if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        @pcol += 1 if @pcol <= row_length
      end
      }
      set_form_col 
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
    end
    def addcol num #:nodoc:
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
        @form.addcol num
      else
        @parent_component.form && @parent_component.form.addcol(num)
      end
    end
    def addrowcol row,col #:nodoc:
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
      @form.addrowcol row, col
      else
        @parent_component.form.addrowcol num
      end
    end
    def cursor_backward  #:nodoc:
      repeatm { 
      if @curpos > 0
        @curpos -= 1
        set_form_col 
        #addcol -1
      elsif @pcol > 0 
        @pcol -= 1   
      end
      }
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
    end
    # gives offset of next line, does not move
    # @deprecated
    def next_line  #:nodoc:
      @list[@current_index+1]
    end
    # @deprecated
    def do_relative_row num  #:nodoc:
      raise "unused will be removed"
      yield @list[@current_index+num] 
    end

    # supply with a color parser, if you supplied formatted text
    def color_parser f
      $log.debug "XXX: parser setting color_parser to #{f} "
      #@window.color_parser f
      @color_parser = f
    end



    ## NOTE: earlier print_border was called only once in constructor, but when
    ##+ a window is resized, and destroyed, then this was never called again, so the 
    ##+ border would not be seen in splitpane unless the width coincided exactly with
    ##+ what is calculated in divider_location.
    def paint  #:nodoc:
    
      $log.debug "XXX TEXTVIEW repaint HAPPENING #{@current_index} "
      my_win = nil
      if @form
        my_win = @form.window
      else
        my_win = @target_window
      end
      @graphic = my_win unless @graphic
      if @formatted_text
        $log.debug "XXX:  INSIDE FORMATTED TEXT "

        # I don't want to do this in 20 places and then have to change
        # it and retest. Let me push it to util.
        l = RubyCurses::Utils.parse_formatted_text(@color_parser,
                                               @formatted_text)

        #cp = Chunks::ColorParser.new @color_parser
        #l = []
        #@formatted_text.each { |e| l << cp.convert_to_chunk(e) }

        @old_content_type = @content_type
        text(l)
        @formatted_text = nil

      end

      print_borders if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      rc = row_count
      maxlen = @maxlen || @width-@internal_width
      #$log.debug " #{@name} textview repaint width is #{@width}, height is #{@height} , maxlen #{maxlen}/ #{@maxlen}, #{@graphic.name} roff #{@row_offset} coff #{@col_offset}" 
      tm = get_content
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow() 
      r,c = rowcol
      @longest_line = @width-@internal_width #maxlen
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            #focussed = @current_index == crow ? true : false 
            #selected = is_row_selected crow
            content = tm[crow]
            # next call modified string. you may wanna dup the string.
            # rlistbox does
            # scrolling fails if you do not dup, since content gets truncated
            if content.is_a? String
              content = content.dup
              sanitize(content) if @sanitization_required
              truncate content
              @graphic.printstring  r+hh, c, "%-*s" % [@width-@internal_width,content], 
                acolor, @attr
            elsif content.is_a? Chunks::ChunkLine
              # clear the line first
              @graphic.printstring  r+hh, c, " "* (@width-@internal_width), 
                acolor, @attr
              # move back
              @graphic.wmove r+hh, c
              # either we have to loop through and put in default color and attr
              # or pass it to show_col
              a = get_attrib @attrib
              # FIXME this does not clear till the eol
              @graphic.show_colored_chunks content, acolor, a, @width-@internal_width
            elsif content.is_a? Chunks::Chunk
              raise "TODO chunk in textview"
            elsif content.is_a? Array
                # several chunks in one row - NOTE Very experimental may change
              if content[0].is_a? Array
                # clearing the line since colored_chunks does not yet XXX FIXME if possible
                @graphic.printstring  r+hh, c, " "* (@width-@internal_width), 
                  acolor, @attr
                @graphic.wmove r+hh, c
                # either we have to loop through and put in default color and attr
                # or pass it to show_col
                a = get_attrib @attrib
                # FIXME this does not clear till the eol
                # # NOTE 2013-03-08 - 17:37 pls add width to avoid overflow
                @graphic.show_colored_chunks content, acolor, a, @width-@internal_width
                #@graphic.show_colored_chunks content, acolor, a
              else
                # a single row chunk - NOTE Very experimental may change
                text = content[1].dup
                sanitize(text) if @sanitization_required
                truncate text
                @graphic.printstring  r+hh, c, "%-*s" % [@width-@internal_width,text], 
                  content[0] || acolor, content[2] || @attr
              end
            end

            # highlighting search results.
            if @search_found_ix == tr+hh
              if !@find_offset.nil?
                # handle exceed bounds, and if scrolling
                if @find_offset1 < maxlen+@pcol and @find_offset > @pcol
                @graphic.mvchgat(y=r+hh, x=c+@find_offset-@pcol, @find_offset1-@find_offset, Ncurses::A_NORMAL, $reversecolor, nil)
                end
              end
            end

        else
          # clear rows
          @graphic.printstring r+hh, c, " " * (@width-@internal_width), acolor,@attr
        end
      end


      @repaint_required = false
      @repaint_footer_required = true
      @repaint_all = false 
      # 2011-10-15 
      @widget_scrolled = false
      @record_changed = false
      @property_changed = false
      @old_pcol = @pcol

    end
    # takes a block, this way anyone extending this class can just pass a block to do his job
    # This modifies the string
    def sanitize content  #:nodoc:

      if content.is_a? String
        content.chomp!
        # trying out since gsub giving #<ArgumentError: invalid byte sequence in UTF-8> 2011-09-11 
        
        content.replace(content.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")) if content.respond_to?(:encode)
        content.gsub!(/[\t\n\r]/, '  ') # don't display tab or newlines
        content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
      else
        content
      end
    end
    # returns only the visible portion of string taking into account display length
    # and horizontal scrolling. MODIFIES STRING
    def truncate content  #:nodoc:
      _maxlen = @maxlen || @width-@internal_width
      _maxlen = @width-@internal_width if _maxlen > @width-@internal_width # take care of decrease in width
      if !content.nil? 
        if content.length > _maxlen # only show maxlen
          @longest_line = content.length if content.length > @longest_line
          #content = content[@pcol..@pcol+maxlen-1] 
          content.replace(content[@pcol..@pcol+_maxlen-1] || "")
        else
          if @pcol > 0
              content.replace(content[@pcol..-1]  || "")
          end
        end
      end
      content
    end
    ## this is just a test of prompting user for a string
    #+ as an alternative to the dialog.
    def getstr prompt, maxlen=80  #:nodoc:
      tabc = Proc.new {|str| Dir.glob(str +"*") }
      config={}; config[:tab_completion] = tabc
      config[:default] = "test"
      config[:display_length] = 11
      $log.debug " inside getstr before call "
      ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
      $log.debug " rbgetstr returned #{ret} ,#{str}."
      return "" if ret != 0
      return str
    end
    ##
    # dynamically load a module and execute init method.
    # Hopefully, we can get behavior like this such as vieditable or multibuffers
    def load_module requirename, includename
      require "rbcurse/#{requirename}"
      extend Object.const_get("#{includename}")
      send("#{requirename}_init") #if respond_to? "#{includename}_init"
    end
    # on pressing ENTER we send user some info, the calling program
    # would bind :PRESS
    #--
    # FIXME we can create this once and reuse
    #++
    def fire_action_event
      return if @list.nil? || @list.size == 0
      require 'rbcurse/core/include/ractionevent'
      aev = TextActionEvent.new self, :PRESS, current_value().to_s, @current_index, @curpos
      fire_handler :PRESS, aev
    end
    # called by listscrollable, used by scrollbar ENTER_ROW
    def on_enter_row arow
      fire_handler :ENTER_ROW, self
      @repaint_required = true
    end
    # added 2010-09-30 18:48 so standard with other components, esp on enter 
    # NOTE: the on_enter repaint required causes this to be repainted 2 times
    # if its the first object, once with the entire form, then with on_enter.
    def on_enter
      if @list.nil? || @list.size == 0
        Ncurses.beep
        return :UNHANDLED
      end
      on_enter_row @current_index
      set_form_row 
      @repaint_required = true
      super
      true
    end
    def pipe_file
      # TODO ask process name from user
      output = pipe_output 'munpack', @list
      if output && !output.empty?
        set_content output
      end
    end
    # returns array of lines after running command on string passed
    # TODO: need to close pipe other's we'll have a process lying
    # around forever.
    def pipe_output (pipeto, str)
      case str
      when String
        #str = str.split "\n"
        # okay
      when Array
        str = str.join "\n"
      end
      #pipeto = '/usr/sbin/sendmail -t'
      #pipeto = %q{mail -s "my title" rahul}
      if pipeto != nil  # i was taking pipeto from a hash, so checking
        proc = IO.popen(pipeto, "w+")
        proc.puts str
        proc.close_write
        proc.readlines
      end
    end
    def saveas name=nil, config={}
      unless name
        name = rb_gets "File to save as: "
        return if name.nil? || name == ""
      end
      exists = File.exists? name
      if exists # need to prompt
        return unless rb_confirm("Overwrite existing file? ")
      end
      l = getvalue
      File.open(name, "w"){ |f|
        l.each { |line| f.puts line }
        #l.each { |line| f.write line.gsub(/\r/,"\n") }
      }
      rb_puts "#{name} written."
    end

    # edit content of textview in EDITOR and bring back
    # NOTE: does not maintain content_type, so if you edit ansi text,
    # it will come back in as normal text
    def edit_external
      require 'rbcurse/core/include/appmethods'
      require 'tempfile'
      f = Tempfile.new("rbcurse")
      l = self.text
      l.each { |line| f.puts line }
      fp = f.path
      f.flush

      editor = ENV['EDITOR'] || 'vi'
      vimp = %x[which #{editor}].chomp
      ret = shell_out "#{vimp} #{fp}"
      if ret
        lines = File.open(f,'r').readlines
        set_content(lines, :content_type => @old_content_type)
      end
    end
    def init_actions
      editor = ENV['EDITOR'] || 'vi'
      am = action_manager()
      am.add_action( Action.new("&Edit in #{editor} ") { edit_external } )
      am.add_action( Action.new("&Saveas") { saveas() })
    end


  end # class textview

end # modul
