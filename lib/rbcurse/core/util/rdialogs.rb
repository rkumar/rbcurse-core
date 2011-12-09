=begin
  * Name: dialogs so user can do basic stuff in one line.
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-30 12:22 
  * 2011-10-1 : moving print_error and print_status methods here as alternatives
                to alert and confirm. Anyone who has included those will get these.
                And this file is included in the base file.

               Shucks, this file has no module. It's bare !
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

# CHANGES:
# -- moving to the new Messagebox 2011-11-19 v 1.5.0
TODO:
    Add select_one (message, values, default)
=end
require 'rbcurse/core/widgets/rwidget'
#require 'rbcurse/deprecated/widgets/rmessagebox'
require 'rbcurse/core/widgets/rmessagebox'

# -- moving to the new Messagebox 2011-11-19 v 1.5.0
# Alert user with a one line message
#
def alert text, config={}

  if text.is_a? RubyCurses::Variable 
    text = text.get_value
  end
  _title = config[:title] || "Alert"
    tp = MessageBox.new config do
      title _title
      button_type :ok
      message text
      #text mess
    end
    tp.run
end

# Alert user with a block of text. This will popup a textview in which the user can scroll
# Use this if you are not sure of the size of the text, such as printing a stack trace,
# exception
def textdialog mess, config={}
  config[:title] ||= "Alert"
  tp = MessageBox.new config do
    button_type :ok
    text mess
  end
  tp.run
end
# 
# This uses the new messagebox 2011-11-19 v 1.5.0
# NOTE: The earlier get_string had only an OK button, this seems to have a CANCEL
# Are we doing anyhting to let caller know, cancel was pressed. FIXME
# @param [String] a label such as "Enter name:"
# @return [String] value entered by user
# @yield [Field] field created by messagebox
def get_string label, config={} # yield Field
  config[:title] ||= "Entry"
  label_config = config[:label_config] || {}
  label_config[:row] ||= 2
  label_config[:col] ||= 2
  label_config[:text] = label

  field_config = config[:field_config] || {}
  field_config[:row] ||= 3
  field_config[:col] ||= 2
  field_config[:attr] = :reverse
  field_config[:maxlen] ||= config[:maxlen]
  field_config[:display_length] ||= config[:display_length]
  field_config[:default] ||= config[:default]
  field_config[:default] = field_config[:default].chomp if field_config[:default]
  field_config[:name] = :name
  #field_config[:display_length] ||= 50  # i want it to extend since i don't know the actual width
  #field_config[:width] ||= 50  # i want it to extend since i don't know the actual width
  field_config[:width] ||= (field_config[:display_length] || 50)

  defwid = config[:default].nil? ? 30 : config[:default].size + 13
  w = [label.size + 8, defwid, field_config[:width]+13 ].max
  config[:width] ||= w
  $log.debug "XXX:  FIELD SIZE #{w} "
  $log.debug "XXX:  FIELD CONFIG #{field_config} "
  tp = MessageBox.new config do
    button_type :ok_cancel
    default_button 0
    item Label.new nil, label_config
    item Field.new nil, field_config
  end
  # added yield to override settings
  yield tp.form.by_name[:name] if block_given?
  index = tp.run
  if index == 0 # OK
    return tp.form.by_name[:name].text
  else # CANCEL
    # Should i use nil or blank. I am currently opting for nil, as this may imply to caller
    # that user does not wish to override whatever value is being prompted for.
    return nil
  end
end
# new version using new messagebox
# @param [String] question
# @return [Boolean] true or false
# @yield [Label]
# 
def confirm text, config={}, &block
  title = config['title'] || "Confirm"
  config[:default_button] ||= 0

  mb = RubyCurses::MessageBox.new config  do
    title title
    message text, &block 
    button_type :yes_no
  end
  index = mb.run
  return index == 0
end
##
# pops up a modal box with a message and an OK button.
# No return value.
# Usage:
# alert("You did not enter anything!")
# alert("You did not enter anything!", "title"=>"Wake Up")
# alert("You did not enter anything!", {"title"=>"Wake Up", "bgcolor"=>"blue", "color"=>"white"})
# block currently ignored. don't know what to do, can't pass it to MB since alread sending in a block
#

# ------------------------ We've Moved here from window class ---------------- #
#                                                                              #
#  Moving some methods from window. They no longer require having a window.    #
#                                                                              #
# ---------------------------------------------------------------------------- #
#
#

# new version with a window created on 2011-10-1 12:37 AM 
# Now can be separate from window class, needing nothing, just a util class
# prints a status message and pauses for a char
# @param [String] text to print
# @param [Hash] config: :color :bgcolor :color_pair
#              :wait (numbr of seconds to wait for a key press and then close) if not givn
#              will keep waiting for keypress (the default)
def print_status_message text, aconfig={}, &block
  _print_message :status, text, aconfig, &block
end
alias :rb_puts print_status_message

# new version with a window created on 2011-10-1 12:30 AM 
# Now can be separate from window class, needing nothing, just a util class
# Why are we dealing with $error_message, that was due to old idea which failed
# scrap it and send the message.
# @param [String] text to print
# @param [Hash] config: :color :bgcolor :color_pair
#              :wait (numbr of seconds to wait for a key press and then close) if not givn
#              will keep waiting for keypress (the default)
def print_error_message text, aconfig={}, &block
  _print_message :error, text, aconfig, &block
end
private
def _create_footer_window h = 2 , w = Ncurses.COLS, t = Ncurses.LINES-2, l = 0  #:nodoc:
  ewin = VER::Window.new(h, w , t, l)
end
# @param [:symbol] :error or :status kind of message
#private
def _print_message type, text, aconfig={}, &block  #:nodoc:
  case text
  when RubyCurses::Variable # added 2011-09-20 incase variable passed
    text = text.get_value
  when Exception
    text = text.to_s
  end
  # NOTE we are polluting global namespace
  # fixed on 2011-12-6 . to test
  #aconfig.each_pair { |k,v| instance_variable_set("@#{k}",v) }
  color = aconfig[:color]
  bgcolor = aconfig[:bgcolor]
  ewin = _create_footer_window #*@layout
  r = 0; c = 1;
  case type 
  when :error
    color ||= 'red'
    bgcolor ||= 'black'
  else
    color ||= :white
    bgcolor ||= :black
  end
  color_pair = get_color($promptcolor, color, bgcolor)
  color_pair = aconfig[:color_pair] || color_pair
  ewin.bkgd(Ncurses.COLOR_PAIR(color_pair));
  ewin.printstring r, c, text, color_pair
  ewin.printstring(r+1, c, "Press a key ", color_pair) unless aconfig[:wait]
  ewin.wrefresh
  if aconfig[:wait]
    #try this out, if user wants a wait, then it will wait for 5 seconds, or if a key is pressed sooner
    value = aconfig[:wait]
    if value.is_a? Fixnum
      value = value * 10
    else 
      value = 50
    end
    Ncurses::halfdelay(tenths = value)
    ewin.getch
    Ncurses::halfdelay(tenths = 10)
  else
    ewin.getchar
  end
  ewin.destroy
end
#
# Alternative to confirm dialog, if you want this look and feel, at last 2 lines of screen
# @param [String] text to prompt
# @return [true, false] 'y' is true, all else if false
public
def rb_confirm text, aconfig={}, &block
  # backward compatibility with agree()
  if aconfig == true || aconfig == false
    default = aconfig
    aconfig = {}
  else 
    default = aconfig[:default]
  end
  case text
  when RubyCurses::Variable # added 2011-09-20 incase variable passed
    text = text.get_value
  when Exception
    text = text.to_s
  end
  ewin = _create_footer_window
  r = 0; c = 1;
  #aconfig.each_pair { |k,v| instance_variable_set("@#{k}",v) }
  # changed on 2011-12-6 
  color = aconfig[:color]
  bgcolor = aconfig[:bgcolor]
  color ||= :white
  bgcolor ||= :black
  color_pair = get_color($promptcolor, color, bgcolor)
  ewin.bkgd(Ncurses.COLOR_PAIR(color_pair));
  ewin.printstring r, c, text, color_pair
  ewin.printstring r+1, c, "[y/n]", color_pair
  ewin.wrefresh
  #retval = :NO # consistent with confirm  # CHANGE TO TRUE FALSE NOW 
  retval = false
  begin
    ch =  ewin.getchar 
    retval = (ch == 'y'.ord || ch == 'Y'.ord )
    # if caller passed a default value and user pressed ENTER return that
    # can be true or false so don't change this to "if default". 2011-12-8 
    if !default.nil?
      if ch == 13 || ch == KEY_ENTER
        retval = default
      end
    end
    #retval = :YES if ch.chr == 'y' 
  ensure
    ewin.destroy
  end
  retval
end
alias :confirm_window :rb_confirm
# class created to display multiple messages without asking for user to hit a key
# returns a window to which one can keep calling printstring with 0 or 1 as row.
# destroy when finished.
# Also, one can pause if one wants, or linger.
# This is meant to be a replacement for the message_immediate and message_raw
# I was trying out in App.rb. 2011-10-1 1:27 AM 
# Testing from test2.rb
# TODO: add option of putting progress_bar
class StatusWindow
  attr_reader :h, :w, :top, :left # height, width, top row, left col of window
  attr_reader :win
  attr_accessor :color_pair
  def initialize config={}, &block
    @color_pair = config[:color_pair]
    @row_offset = config[:row_offset] || 0
    @col_offset = config[:col_offset] || 0
    create_window *config[:layout]
  end
  def create_window h = 2 , w = Ncurses.COLS-0, t = Ncurses.LINES-2, l = 0
    return @win if @win
    @win = VER::Window.new(h, w , t, l)
    @h = h ; @w = w; @top = t ; @left = l
    @color_pair ||= get_color($promptcolor, 'white','black')
    @win.bkgd(Ncurses.COLOR_PAIR(@color_pair));
    @win
  end
  # creates a color pair based on given bg and fg colors as strings
  #def set_colors bgcolor, fgcolor='white'
  #@color_pair = get_color($datacolor, 'white','black')
  #end
  # prints a string on given row (0 or 1)
  def printstring r, c, text, color_pair=@color_pair
    create_window unless @win
    show unless @visible
    r = @h-1 if r > @h-1
    #@win.printstring r, c, ' '*@w, @color_pair
    # FIXME this padding overwrites the border and the offset means next line wiped
    # However, now it may now totally clear a long line.
    @win.printstring r+@row_offset, c+@col_offset, "%-*s" % [@w-(@col_offset*2)-c, text], color_pair
    @win.wrefresh
  end
  # print given strings from first first column onwards
  def print *textarray
    create_window unless @win
    show unless @visible
    c = 1
    textarray.each_with_index { |s, i|  
      @win.printstring i+@row_offset, c+@col_offset, "%-*s" % [@w-(@col_offset*2)-c, s], @color_pair
    }
    @win.wrefresh
  end
  def pause; @win.getchar; end
  # pauses with the message, but doesn't ask the user to press a key.
  # If he does, the key should be used by underlying window.
  # Do not call destroy if you call linger, it does the destroy.
  def linger caller_window=nil
    begin
      if caller_window
        ch = @win.getchar
        caller_window.ungetch(ch) # will this be available to underlying window XXX i think not !!
      else
        sleep 1
      end
    ensure
      destroy
    end
  end
  # caller must destroy after he's finished printing messages, unless
  # user calls linger
  def destroy; @win.destroy if @win; @win = nil;  end
  def hide
    @win.hide
    @visible = false
  end
  def show
    @win.show unless @visible
    @visible = true
  end
end
# returns instance of a status_window for sending multiple
# statuses during some process
def status_window aconfig={}, &block
  return StatusWindow.new aconfig
end
# this is a popup dialog box on which statuses can be printed as a process is taking place.
# I am reusing StatusWindow and so there's an issue since I've put a box, so in clearing 
# the line, I might overwrite the box
def progress_dialog aconfig={}, &block
  aconfig[:layout] = [10,60,10,20]
  window = status_window aconfig
  height = 10; width = 60
  window.win.print_border_mb 1,2, height, width, $normalcolor, FFI::NCurses::A_REVERSE
  return window
end
# 
# Display a popup and return the seliected index from list
#  Config includes row and col and title of window
#  You may also pass bgcolor and color
#  @since 1.4.1  2011-11-1 
def popuplist list, config={}, &block
  raise ArgumentError, "Nil list received by popuplist" unless list
  require 'rbcurse/core/widgets/rlist'

  max_visible_items = config[:max_visible_items]
  row = config[:row] || 5
  col = config[:col] || 5
  relative_to = config[:relative_to]
  if relative_to
    layout = relative_to.form.window.layout
    row += layout[:top]
    col += layout[:left]
  end
  config.delete :relative_to
  width = config[:width] || longest_in_list(list)+2 # borders take 2
  height = config[:height]
  height ||= [max_visible_items || 10+2, list.length+2].min 
  #layout(1+height, width+4, row, col) 
  layout = { :height => 0+height, :width => 0+width, :top => row, :left => col } 
  window = VER::Window.new(layout)
  form = RubyCurses::Form.new window

  listconfig = config[:listconfig] || {}
  listconfig[:list] = list
  listconfig[:width] = width
  listconfig[:height] = height
  listconfig[:selection_mode] ||= :single
  listconfig.merge!(config)
  listconfig.delete(:row); 
  listconfig.delete(:col); 
  # trying to pass populists block to listbox
  lb = RubyCurses::List.new form, listconfig, &block
  #
  # added next line so caller can configure listbox with 
  # events such as ENTER_ROW, LEAVE_ROW or LIST_SELECTION_EVENT or PRESS
  # 2011-11-11 
  #yield lb if block_given? # No it won't work since this returns
  window.bkgd(Ncurses.COLOR_PAIR($reversecolor));
  window.wrefresh
  Ncurses::Panel.update_panels
  form.repaint
  window.wrefresh
  begin
    while((ch = window.getchar()) != 999 )
      case ch
      when -1
        next
      when ?\C-q.getbyte(0)
        break
      else
        lb.handle_key ch
        form.repaint
        if ch == 13 || ch == 10
          return lb.current_index if lb.selection_mode != :multiple

          x = lb.selected_indices
          return x if x
          x = lb.current_index unless x
          return [x]
          # if multiple selection, then return list of selected_indices and don't catch 32
        elsif ch == 32      # if single selection
          return lb.current_index if lb.selection_mode != :multiple
        end
        #yield ch if block_given?
      end
    end
  ensure
    window.destroy  
  end
  return nil
end
# returns length of longest
def longest_in_list list  #:nodoc:
  raise ArgumentError, "rdialog.rb: longest_in_list recvd nil list" unless list
  longest = list.inject(0) do |memo,word|
    memo >= word.length ? memo : word.length
  end    
  longest
end    
def install_help_text text
  @_help_text = text
end
# this routine prints help_text for an application
# If help_text has been set using install_help_text
# it will be displayed. Else, general help will be
# displayed. Even when custom help is displayed,
# user may use <next> to see general help.
#
# earlier in app.rb
def display_app_help
  filename = File.dirname(__FILE__) + "/../docs/index.txt"
  # defarr contains default help
  if File.exists?(filename)
    defarr = File.open(filename,'r').readlines
  else
    arr = []
    arr << "    NO HELP SPECIFIED FOR APP "
    arr << "    "
    arr << "     --- General help ---          "
    arr << "    F10         -  exit application "
    arr << "    Alt-x       -  select commands  "
    arr << "    :           -  select commands  "
    arr << "    "
    defarr = arr
  end
  defhelp = true
  if respond_to? :help_text
    arr = help_text
    defhelp = false
  elsif @_help_text
    arr = @_help_text
    defhelp = false
  else
    arr = defarr
  end
  case arr
  when String
    arr = arr.split("\n")
  when Array
  end
  #w = arr.max_by(&:length).length
  h = FFI::NCurses.LINES - 4
  w = FFI::NCurses.COLS - 10

    require 'rbcurse/core/util/viewer'
    RubyCurses::Viewer.view(arr, :layout => [2, 4, h, w],:close_key => KEY_F10, :title => "[ Help ]", :print_footer => true) do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      #t.attr = :reverse

      # help was provided, so default help is provided in second buffer
      unless defhelp
        t.add_content defarr, :title => ' General Help '
      end
    end
end
#
=begin  
http://www.kammerl.de/ascii/AsciiSignature.php
 ___  
|__ \ 
   ) |
  / / 
 |_|  
 (_)  

 _ 
| |
| |
| |
|_|
(_)


 _____       _              _____                         
|  __ \     | |            / ____|                        
| |__) |   _| |__  _   _  | |    _   _ _ __ ___  ___  ___ 
|  _  / | | | '_ \| | | | | |   | | | | '__/ __|/ _ \/ __|
| | \ \ |_| | |_) | |_| | | |___| |_| | |  \__ \  __/\__ \
|_|  \_\__,_|_.__/ \__, |  \_____\__,_|_|  |___/\___||___/
                    __/ |                                 
                   |___/                                  

=end


