# this program tests out a listbox
# This is written in the old style where we start and end ncurses and initiate a 
# getch loop. It gives more control.
# The new style is to use App which does the ncurses setup and teardown, as well
# as manages keys. It also takes care of logger and includes major stuff.
require 'logger'
require 'rbcurse'
require 'rbcurse/core/widgets/rlist'
require 'rbcurse/core/widgets/rtextview'
require 'rbcurse/core/include/vieditable'
#require 'rbcurse/experimental/widgets/undomanager'
class RubyCurses::List
  # vieditable includes listeditable which
  # does bring in some functions which can crash program like x and X TODO
  # also, f overrides list f mapping. TODO
  include ViEditable
end
  def my_help_text
    <<-eos

    =========================================================================
    Basic Usage

    Press <ENTER> on a class name on the first list, to view ri information
    for it on the right.
    
    Tab to right area, and press <ENTER> on a method name, to see its details
    Press / <slash> in any box to search. e.g /String will take you to the
    first occurrence of String. <n> will take you to next.
    
    To go quickly to first class starting with 'S', type <f> followed by <S>.
    Then press <n> to go to next match.
    
    =========================================================================
    Vim Edit Keys

    The list on left has some extra vim keys enabled such as :
    yy     - yank/copy current line/s
    P, p   - paste after or before
    dd     - delete current line
    o      - insert a line after this one
    C      - change content of current line
    These are not of use here, but are demonstrative of list capabilities.

    =========================================================================
    Buffers

    Ordinary a textview contains only one buffer. However, the one on the right
    is extended for multiple buffers. Pressing ENTER on the left on several 
    rows opens multiple buffers on the right. Use M-n (Alt-N) and M-p to navigate.
    ALternatively, : maps to a menu, so :n and :p may also be used.
    <BACKSPACE> will also go to previous buffer, like a browser.

    =========================================================================
           Press <M-n> for next help screen, or try :n 

    eos
  end
if $0 == __FILE__
  include RubyCurses

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")))
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window
    $catch_alt_digits = true; # emacs like alt-1..9 numeric arguments
    install_help_text my_help_text
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      @form = Form.new @window
      @form.bind_key(KEY_F1, 'help'){ display_app_help }

      # this is the old style of printing something directly on the window.
      # The new style is to use a header
      @form.window.printstring 0, 30, "Demo of Listbox - some vim keys", $normalcolor, BOLD
      r = 1; fc = 1;

      # this is the old style of using a label at the screen bottom, you can use the status_line
      
      v = "F10 quits. F1 Help.  Try j k gg G o O C dd f<char> w yy p P / . Press ENTER on Class or Method"
      var = RubyCurses::Label.new @form, {'text' => v, "row" => FFI::NCurses.LINES-2, 
        "col" => fc, "display_length" => 100}

      h = FFI::NCurses.LINES-3
      file = "./data/ports.txt"
      #mylist = File.open(file,'r').readlines 
      mylist = `ri -f bs`.split("\n")
      w = 25
      #0.upto(100) { |v| mylist << "#{v} scrollable data" }
      #
      listb = List.new @form, :name   => "mylist" ,
        :row  => r ,
        :col  => 1 ,
        :width => w,
        :height => h,
        :list => mylist,
        :selection_mode => :SINGLE,
        :show_selector => true,
        #row_selected_symbol "[X] "
        #row_unselected_symbol "[ ] "
        :title => " Ruby Classes "
        #title_attrib 'reverse'
      listb.one_key_selection = false # this allows us to map keys to methods
      listb.vieditable_init_listbox
      include Io
      listb.bind_key(?r, 'get file'){ get_file("Get a file:", 70) }
      listb.bind(:PRESS) { 
        w = @form.by_name["tv"]; 
        lines = `ri -f bs #{listb.text}`.split("\n")
        #w.set_content(lines, :ansi)
        w.add_content(lines, :content_type => :ansi, :title => listb.text)
        w.buffer_last
        #w.title = listb.text
      }

      tv = RubyCurses::TextView.new @form, :row => r, :col => w+1, :height => h, :width => FFI::NCurses.COLS-w-1,
      :name => "tv", :title => "Press Enter on method"
      tv.set_content ["Press Enter on list to view ri information in this area.", 
        "Press ENTER on method name to see details"]
      require 'rbcurse/core/include/multibuffer'
      tv.extend(RubyCurses::MultiBuffers)

      # pressing ENTER on a method name will popup details for that method
      tv.bind(:PRESS) { |ev|
        w = ev.word_under_cursor.strip
        # check that user did not hit enter on empty area
        if w != ""
          text = `ri -f bs #{tv.title}.#{w}` rescue "No details for #{w}"
          text = text.split("\n")
          view(text, :content_type => :ansi)
        end
      }


    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    while((ch = @window.getchar()) != KEY_F10 )
      @form.handle_key(ch)
      @window.wrefresh
    end
  end
rescue => ex
  $log.debug( ex) if ex
  $log.debug(ex.backtrace.join("\n")) if ex
ensure
  @window.destroy if !@window.nil?
  VER::stop_ncurses
  p ex if ex
  p(ex.backtrace.join("\n")) if ex
end
end
