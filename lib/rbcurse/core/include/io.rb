#*******************************************************
# Some common io routines for getting data or putting
# at some point
# Arunachalesha                       
#  2010-03-06 12:10 
#  Some are outdated.
#  Current are:
#    * rbgetstr (and those it calls)
#    * display_cmenu and create_mitem
# Changes:
# 2011-12-6 : removed many old, outdated methods.
#*******************************************************#
module Io

  # create a 2 line window at bottom to accept user input
  # 
  def __create_footer_window h = 2 , w = Ncurses.COLS, t = Ncurses.LINES-2, l = 0
    ewin = VER::Window.new(h, w , t, l)
  end
  # 2011-11-27 I have replaced the getting of chars with a field

  # routine to get a string at bottom of window.
  # The first 3 params are no longer required since we create a window
  # of our own. 
  # @param [String] prompt - label to show
  # @param [Fixnum] maxlen - max length of input
  # @param [Hash] config - :default, :display_length of Field, :help_text, :tab_completion
  # help_text is displayed on F1
  # tab_completion is a proc which helps to complete user input
  # This method is now only for backward compatibility
  def rbgetstr(nolongerused, r, c, prompt, maxlen, config={})
    config[:maxlen] = maxlen
    rb_gets(prompt, config)
  end

  # get a string at the bottom of the screen
  #
  # @param [String] prompt - label to show
  # @param [Hash] config - :default, :display_length of Field, :help_text, :tab_completion
  # help_text is displayed on F1
  # tab_completion is a proc which helps to complete user input
  # @yield [Field] for overriding or customization
  def rb_gets(prompt, config={}) # yield field
    _max = FFI::NCurses.COLS-1
    begin
      win = __create_footer_window
      form = Form.new win
      r = 0; c = 1;
      default = config[:default] || ""
      displen = config[:display_length] || config[:maxlen] || _max
      prompt = "#{prompt} [#{default}]: " unless default
      maxlen = config[:maxlen] || _max
      field = Field.new form, :row => r, :col => c, :maxlen => maxlen, :default => default, :label => prompt,
        :display_length => displen
      field.bgcolor = :blue
      field.cursor_end if default.size > 0
      yield field if block_given?
      #require 'rbcurse/core/include/rhistory'
      #field.extend(FieldHistory)
      #field.history_config :row => FFI::NCurses.LINES-12
      #field.history %w[ jim john jack ruby jane jill just testing ]
      form.repaint
      win.wrefresh
      prevchar = 0
      entries = nil
      while ((ch = win.getchar()) != 999)
        break if ch == 10 || ch == 13
        return -1, nil if ch == ?\C-c.getbyte(0) || ch == ?\C-g.getbyte(0)
        #if ch == ?\M-h.getbyte(0) #                            HELP KEY
        #help_text = config[:help_text] || "No help provided"
        #color = $datacolor
        #print_help(win, r, c, color, help_text)
        ## this will come over our text
        #end
        # TODO tab completion and help_text print on F1
        # that field objects can extend, same for tab completion and gmail completion
        if ch == KEY_TAB
          if config
            str = field.text
            if prevchar == 9
              if !entries.nil? && !entries.empty?
                str = entries.delete_at(0)
              end
            else
              tabc = config[:tab_completion] unless tabc
              next unless tabc
              entries = tabc.call(str)
              $log.debug " tab got #{entries} "
              str = entries.delete_at(0) unless entries.nil? || entries.empty?
            end
            if str
              field.text = str
              field.cursor_end
              field.set_form_col # shit why are we doign this, text sets curpos to 0
            end
            form.repaint
            win.wrefresh
          end

          # tab_completion
          # if previous char was not tab, execute tab_completion_proc and push first entry
          # else push the next entry
        elsif ch == KEY_F1
          help_text = config[:help_text] || "No help provided. C-c/C-g aborts. <TAB> completion. Alt-h history. C-a/e"
          print_status_message help_text, :wait => 7
        end
        prevchar = ch
        form.handle_key ch
        win.wrefresh
      end
    rescue => err
      Ncurses.beep
      $log.error "EXC in rbgetsr #{err} "
      $log.error(err.backtrace.join("\n")) 
    ensure
      win.destroy if win
    end
    return 0, field.text
  end

  # This is just experimental, trying out tab_completion
  # Prompt user for a file name, allowing him to tab to complete filenames
  # @param [String] label to print before field
  # @param [Fixnum] max length of field
  # @return [String] filename or blank if user cancelled
  def get_file prompt, config={}  #:nodoc:
    maxlen = 70
    tabc = Proc.new {|str| Dir.glob(str +"*") }
    config[:tab_completion] ||= tabc
    #config[:default] = "test"
    ret, str = rbgetstr(nil,0,0, prompt, maxlen, config)
    #$log.debug " get_file returned #{ret} , #{str} "
    return "" if ret != 0
    return str
  end
  def clear_this win, r, c, color, len
    print_this(win, "%-*s" % [len," "], color, r, c)
  end



  ##
  # prints given text to window, in color at x and y coordinates
  # @param [Window] window to write to
  # @param [String] text to print
  # @param [int] color pair such as $datacolor or $promptcolor
  # @param [int] x  row
  # @param [int] y  col
  # @see Window#printstring
  def print_this(win, text, color, x, y)
    raise "win nil in print_this" unless win
    color=Ncurses.COLOR_PAIR(color);
    win.attron(color);
    #win.mvprintw(x, y, "%-40s" % text);
    win.mvprintw(x, y, "%s" % text);
    win.attroff(color);
    win.refresh
  end


  #
  # warn user: currently flashes and places error in log file
  # experimental, may change interface later
  # it does not say anything on screen
  # @param [String] text of error/warning to put in log
  # @since 1.1.5
  def warn string
    $log.warn string
    Ncurses.beep
  end

  #def add_item hotkey, label, desc,action
  #
  ## A *simple* way of creating menus that will appear in a single row.
  # This copies the menu at the bottom of "most" upon pressing ":".
  # hotkey is the key to invoke an item (a single digit letter)
  #
  # label is an action name
  #
  # desc is a description displayed after an item is chosen. Usually, its like:
  #+ "Folding has been enabled" or "Searches will now be case sensitive"
  #
  # action may be a Proc or a symbol which will be called if item selected
  #+ action may be another menu, so recursive menus can be built, but each
  #+ should fit in a line, its a simple system.

  CMenuItem = Struct.new( :hotkey, :label, :desc, :action )


  ## An encapsulated form of yesterday's Most Menu
  # It keeps the internals away from the user.
  # Its not really OOP in the sense that the PromptMenu is not a MenuItem. That's how it is in
  # our Menu system, and that led to a lot of painful coding (at least for me). This is quite
  # simple. A submenu contains a PromptMenu in its action object and is evaluated in a switch.
  # A recursive loop handles submenus.
  #
  # Prompting of menu options with suboptions etc.
  # A block of code or symbol or proc is executed for any leaf node
  # This allows us to define different menus for different objects on the screen, and not have to map 
  # all kinds of control keys for operations, and have the user remember them. Only one key invokes the menu
  # and the rest are ordinary characters.
  # 
  #  == Example
  #    menu = PromptMenu.new self do
  #      item :s, :goto_start
  #      item :b, :goto_bottom
  #      item :r, :scroll_backward
  #      item :l, :scroll_forward
  #      submenu :m, "submenu" do
  #        item :p, :goto_last_position
  #        item :r, :scroll_backward
  #        item :l, :scroll_forward
  #      end
  #    end
  #    menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu

  class PromptMenu
    include Io
    attr_reader :text
    attr_reader :options
    def initialize caller,  text="Choose:", &block
      @caller = caller
      @text = text
      @options = []
      instance_eval &block if block_given?
    end
    def add *menuitem
      item = nil
      case menuitem.first
      when CMenuItem
        item = menuitem.first
        @options << item
      else
        case menuitem.size
        when 4
          item = CMenuItem.new(*menuitem.flatten)
        when 2
          # if user only sends key and symbol
          menuitem[3] = menuitem[1]
          item = CMenuItem.new(*menuitem.flatten)
        end
        @options << item
      end
      return item
    end
    alias :item :add
    def create_mitem *args
      item = CMenuItem.new(*args.flatten)
    end
    # create the whole thing using a MenuTree which has minimal information.
    # It uses a hotkey and a code only. We are supposed to resolve the display text
    # and actual proc from the caller using this code.
    def menu_tree mt, pm = self
      mt.each_pair { |ch, code| 
        if code.is_a? RubyCurses::MenuTree
          item = pm.add(ch, code.value, "") 
          current = PromptMenu.new @caller, code.value
          item.action = current
          menu_tree code, current
        else
          item = pm.add(ch, code.to_s, "", code) 
        end
      }
    end
    # 
    # To allow a more rubyesque way of defining menus and submenus
    def submenu key, label, &block
      item = CMenuItem.new(key, label)
      @options << item
      item.action = PromptMenu.new @caller, label, &block
    end
    #
    # Display prompt_menu in columns using commandwindow
    # This is an improved way of showing the "most" like menu. The earlier
    # format would only print in one row.
    #
    def display_columns config={}
      prompt = config[:prompt] || "Choose: "
      require 'rbcurse/core/util/rcommandwindow'
      layout = { :height => 5, :width => Ncurses.COLS-1, :top => Ncurses.LINES-6, :left => 0 }
      rc = CommandWindow.new nil, :layout => layout, :box => true, :title => config[:title] || "Menu"
      w = rc.window
      r = 4
      c = 1
      color = $datacolor
      begin
        menu = @options
        $log.debug " DISP MENU "
        ret = 0
        len = 80
        while true
          h = {}
          valid = []
          labels = []
          menu.each{ |item|
            hk = item.hotkey.to_s
            labels << "%c. %s " % [ hk, item.label ]
            h[hk] = item
            valid << hk
          }
          #$log.debug " valid are #{valid} "
          color = $datacolor
          #print_this(win, str, color, r, c)
          rc.display_menu labels, :indexing => :custom
          ch=w.getchar()
          rc.clear
          #$log.debug " got ch #{ch} "
          next if ch < 0 or ch > 255
          if ch == 3 || ch == ?\C-g.getbyte(0)
            clear_this w, r, c, color, len
            print_this(w, "Aborted.", color, r,c)
            break
          end
          ch = ch.chr
          index = valid.index ch
          if index.nil?
            clear_this w, r, c, color, len
            print_this(w, "Not valid. Valid are #{valid}. C-c/C-g to abort.", color, r,c)
            sleep 1
            next
          end
          #$log.debug " index is #{index} "
          item = h[ch]
          desc = item.desc
          #desc ||= "Could not find desc for #{ch} "
          desc ||= ""
          clear_this w, r, c, color, len
          print_this(w, desc, color, r,c)
          action = item.action
          case action
            #when Array
          when PromptMenu
            # submenu
            menu = action.options
            title = rc.title
            rc.title title +" => " + action.text # set title of window to submenu
          when Proc
            ret = action.call
            break
          when Symbol
            if @caller.respond_to?(action, true)
              $log.debug "XXX:  IO caller responds to action #{action} "
              ret = @caller.send(action)
            elsif @caller.respond_to?(:execute_this, true)
              ret = @caller.send(:execute_this, action)
            else
              alert "PromptMenu: unidentified action #{action} for #{@caller.class} "
              raise "PromptMenu: unidentified action #{action} for #{@caller.class} "
            end

            break
          else 
            $log.debug " Unidentified flying class #{action.class} "
            break
          end
        end # while
      ensure
        rc.destroy
        rc = nil
      end
    end
    alias :display_new :display_columns

    # Display the top level menu and accept user input
    # Calls actions or symbols upon selection, or traverses submenus
    # @return retvalue of last call or send, or 0
    # @param win window
    # @param r, c row and col to display on
    # @param color text color (use $datacolor if in doubt)
    # @see display_new - it presents in a much better manner
    # and is not restricted to one row. Avoid this.
    def display win, r, c, color
      raise "Please use display_new, i've replace this with that"
      # FIXME use a oneline window, user should not have to give all this crap.
      # What about panning if we can;t fit, should we use horiz list to show ?
      menu = @options
      $log.debug " DISP MENU "
      ret = 0
      while true
        str = @text.dup
        h = {}
        valid = []
        menu.each{ |item|
          hk = item.hotkey.to_s
          str << "(%c) %s " % [ hk, item.label ]
          h[hk] = item
          valid << hk
        }
        #$log.debug " valid are #{valid} "
        color = $datacolor
        print_this(win, str, color, r, c)
        ch=win.getchar()
        #$log.debug " got ch #{ch} "
        next if ch < 0 or ch > 255
        if ch == 3 || ch == ?\C-g.getbyte(0)
          clear_this win, r, c, color, str.length
          print_this(win, "Aborted.", color, r,c)
          break
        end
        ch = ch.chr
        index = valid.index ch
        if index.nil?
          clear_this win, r, c, color, str.length
          print_this(win, "Not valid. Valid are #{valid}", color, r,c)
          sleep 1
          next
        end
        #$log.debug " index is #{index} "
        item = h[ch]
        desc = item.desc
        #desc ||= "Could not find desc for #{ch} "
        desc ||= ""
        clear_this win, r, c, color, str.length
        print_this(win, desc, color, r,c)
        action = item.action
        case action
          #when Array
        when PromptMenu
          # submenu
          menu = action.options
          str = "%s: " % action.text 
        when Proc
          ret = action.call
          break
        when Symbol
          ret = @caller.send(action)
          break
        else 
          $log.debug " Unidentified flying class #{action.class} "
          break
        end
      end # while
      return ret # ret val of last send or call
    end
  end # class PromptMenu

  ### ADD HERE ###  

end # module
