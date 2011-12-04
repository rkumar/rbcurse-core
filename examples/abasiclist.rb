require 'rbcurse/core/util/app'
require 'rbcurse/core/include/appmethods'
require 'rbcurse/core/widgets/rlist'

  def my_help_text
    <<-eos
    abasiclist.rb
    =========================================================================
    Basic Usage

    This simple example shows 2 lists inside a "flow". Each takes 50 percent
    of the screen's width. 

    If you have brew installed, you can refresh the list to show actual
    brew packages on your system, using ':r'. Then you can view info, edit,
    or see the man page for that program.

    In the second list, you can refresh the list with your gems using ":r".
    Place cursor on any gem, and execute any of the ":" commands to see the 
    output. "edit" shells out to your EDITOR.

    You can try multiple selection using <space> and <ctrl-space> for range 
    select. Check the general help screen for more _list_ commands. The selections
    are not mapped to any command.

    =========================================================================
    :n or Alt-n for next buffer. 'q' to quit.

    eos
  end



# just a simple test to ensure that rbasiclistbox is running inside a container.
App.new do 
  def disp_menu
    f = @form.get_current_field

    if f.name == "lb1"
      menu = PromptMenu.new self do
        item :r, :refresh
        item :i, :info
        item :m, :brew_man
        item :e, :edit
      end
    else
      menu = PromptMenu.new self do
        item :r, :refresh
        item :e, :edit
        item :d, :dependency
        item :s, :specification
        item :w, :which
      end
    end
    #menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
    menu.display_new :title => "Menu"
  end
  # fill list with actual gems available on your system
  def refresh
    f = @form.get_current_field
    if f.name == "lb2"
      l = %x[gem list --local].split("\n")
      w = @form.by_name['lb2']
      w.list l
    else
      l = %x[brew list].split("\n")
      w = @form.by_name['lb1']
      w.list l
    end
  end
  def specification
    w = @form.by_name['lb2']
    name = w.text.split()[0]
    textdialog(%x[ gem specification #{name} ].split("\n") )
  end

  # execute just man for the brew package
  def brew_man
    w = @form.by_name['lb1']
    name = w.text.split()[0]
    shell_out "man #{name}"
  end

  # using gem which to get path, and then shelling out to EDITOR
  def edit
    f = @form.get_current_field
    if f.name == "lb2"
      name = f.text.split()[0]
      shell_out "gem edit #{name}"
    else
      name = f.text.split()[0]
      shell_out "brew edit #{name}"
    end
    return

    # this is our own home-cooked version which opens the actual file in your editor
    res = %x[ gem which #{name} ].split("\n")
    res = res[0]
    if File.exists? res
      require './common/file.rb'
      file_edit res
    end
  end
  #
  # general purpose command to catch miscellaneous actions that can be 
  # executed in the same way. Or even take complex command lines
  # such as what vim has.
  def execute_this *cmd
    f = @form.get_current_field
    if f.name == "lb2"
      m = "gem"
    else
      m = "brew"
    end
    w = f
    name = w.text.split()[0]
    cmd = cmd[0].to_s
    res = %x[ #{m} #{cmd} #{name}].split("\n")
    res ||= "Error in command [#{cmd}] [#{name}] "
    textdialog( res ) if res
  end

  colors = Ncurses.COLORS
  back = :blue
  back = 234 if colors >= 256
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Basic List Demo", :text_right =>"New Improved!", :color => :white, :bgcolor => back #, :attr => :bold 
  message "Press F10 to escape from here"
  install_help_text my_help_text

  alist = File.open("data/brew.txt",'r').readlines
  list2 = File.open("data/gemlist.txt",'r').readlines
  lb = nil

  flow :margin_top => 1, :height => FFI::NCurses.LINES-2 do
    lb = listbox :list => alist, :suppress_borders => false, :title => "[ brew packages ]",
      :left_margin => 1, :width_pc => 50, :name => 'lb1'
    lb.show_selector = false
    
    lb2 = listbox :list => list2, :justify => :left, :title => "[ gems ]", :suppress_borders => false,
      :left_margin => 1, :width_pc => 50, :name => 'lb2'
    end
  
 
  label({:text => "F1 Help, F10 Quit. Press F4 and F5 to test popup, space or enter to select", :row => Ncurses.LINES-1, :col => 0})

  @form.bind_key(FFI::NCurses::KEY_F4) { row = lb.current_index+lb.row; col=lb.col+lb.current_value.length+1;  ret = popuplist(%w[ andy berlioz strauss tchaiko matz beethoven], :row => row, :col => col, :title => "Names", :bgcolor => :blue, :color => :white) ; alert "got #{ret} "}

  @form.bind_key(FFI::NCurses::KEY_F5) {  list = %x[ls].split("\n");ret = popuplist(list, :title => "Files"); alert "Got #{ret} #{list[ret]} " }

  @form.bind_key(?:) { disp_menu; 
  }
end # app
