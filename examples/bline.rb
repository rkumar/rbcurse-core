require 'rbcurse/core/util/app'
require 'rbcurse/core/util/bottomline'
require 'fileutils'

# this will go into top namespace so will conflict with other apps!
def testnumberedmenu
  list1 =  %w{ ruby perl python erlang rake java lisp scheme chicken }
  list1[0] = %w{ ruby ruby1.9 ruby1.8.x jruby rubinius ROR }
  list1[5] = %w{ java groovy grails }
  str = numbered_menu list1, { :title => "Languages: ", :prompt => "Select :" }
  $log.debug "17 We got #{str.class} "
  message "We got #{str} "
end
def testdisplay_list
  # scrollable list
  text = Dir.glob "*.rb"
  $log.debug "XXX:  DDD got #{text.size} "
  str = display_list text, :title => "Select a file"
  $log.debug "23 We got #{str} :  #{str.class} , #{str.list[str.current_index]}  "
  file = str.list[str.current_index]
  #message "We got #{str.list[str.current_index]} "
  show file
end
def testdisplay_text
  str = display_text_interactive File.read($0), :title => "#{$0}"
end
def testdir
  # this behaves like vim's file selector, it fills in values
  str = ask("File?  ", Pathname)  do |q| 
    q.completion_proc = Proc.new {|str| Dir.glob(str +"*").collect { |f| File.directory?(f) ? f+"/" : f  } }
    q.help_text = "Enter start of filename and tab to get completion"
  end
  message "We got #{str} "
  show str
end
# if components have some commands, can we find a way of passing the command to them
# method_missing gave a stack overflow.
def execute_this(meth, *args)
  alert " #{meth} not found ! "
  $log.debug "app email got #{meth}  " if $log.debug? 
  cc = @form.get_current_field
  [cc].each do |c|  
    if c.respond_to?(meth, true)
      c.send(meth, *args)
      return true
    end
  end
  false
end

App.new do 
  def show file
    w = @form.by_name["tv"]
    if File.exists? file
      lines = File.open(file,'r').readlines 
      w.text lines
      w.title "[ #{file} ]"
    end
  end
  def testchoose
    # list filters as you type
    $log.debug "called CHOOSE " if $log.debug? 
    filter = "*"
    filter = ENV['PWD']+"/*"
    str = choose filter, :title => "Files", :prompt => "Choose a file: (Alt-h Help) ", 
      :help_text => "Enter first char/s and tab to complete filename. Scroll with C-n, C-p"
    if str
      message "We got #{str} " 
      show str
    end
  end
  ht = 24
  borderattrib = :reverse
  @header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Bottomline Test", 
    :text_right =>"Click :", :color => :white, :bgcolor => 235
  message "Press F10 to exit, F1 Help, : for Menu  "


    
    # commands that can be mapped to or executed using M-x
    # however, commands of components aren't yet accessible.
    def get_commands
      %w{ testchoose testnumberedmenu testdisplay_list testdisplay_text testdir }
    end
    def help_text
      <<-eos
               BOTTOMLINE HELP 

      These are some features for either getting filenames from user
      at the bottom of the window like vim and others do.

      :        -   Command mode
      F1       -   Help
      F10      -   Quit application

      Some commands for using bottom of screen as vim and emacs do.
      These may be selected by pressing ':'

      testchoose       - filter directory list as you type
      testdir          - vim style, tabbing completes matching files
      testnumberedmenu - use menu indexes to select options
      testdisplaylist  - display a list at bottom of screen
                         Press <ENTER> to select.
      testdisplaytext  - display text at bottom (current file contents)
                         Press <ENTER> when done.

      The file/dir selection options are very minimally functional. Improvements
      and thorough testing are required. I've only tested them out gingerly.

      -----------------------------------------------------------------------
      :n or Alt-n for general help.
      eos
    end

    #install_help_text help_text

    def app_menu
      menu = PromptMenu.new self do
        item :c, :testchoose
        item :d, :testdir
        item :n, :testnumberedmenu
        item :l, :testdisplay_list
        item :t, :testdisplay_text
      end
      menu.display_new :title => "Menu"
    end
  @form.bind_key(?:) { app_menu; }

  stack :margin_top => 1, :margin_left => 0, :width => :expand , :height => FFI::NCurses.LINES-2 do
    tv = textview :height_pc => 100, :width_pc => 100, :name => "tv"
  end # stack
    
  sl = status_line :row => Ncurses.LINES-1
  testdisplay_list 
end # app
