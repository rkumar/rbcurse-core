# this is a test program, tests out tabbed panes. type F1 to exit
#
require 'logger'
require 'rbcurse'
#require 'rbcurse/core/widgets/newtabbedpane'
require 'rbcurse/core/widgets/rtabbedpane'
require 'rbcurse/core/widgets/rcontainer' # tempo FIXME remove this since we arent using afterfixing rtabbedp

class TestTabbedPane
  def initialize
    acolor = $reversecolor
    #$config_hash ||= {}
  end
  def run
    $config_hash ||= Variable.new Hash.new
    #configvar.update_command(){ |v| $config_hash[v.source()] = v.value }
    @window = VER::Window.root_window
    @form = Form.new @window
    r = 1; c = 30;
      tp = RubyCurses::TabbedPane.new @form, :height => 12, :width  => 50,
        :row => 13, :col => 10 do
        button_type :ok
      end
      tp.add_tab "&Language" do
        _r = 2
        colors = [:red, :green, :cyan]
        %w[ ruby jruby macruby].each_with_index { |e, i| 
          item RadioButton.new nil, 
            :variable => $config_hash,
            :name => "radio1",
            :text => e,
            :value => e,
            :color => colors[i],
            :row => _r+i,
            :col => 5
        }
      end
      tp.add_tab "&Settings" do
        r = 2
        butts = [ "Use &HTTP/1.0", "Use &frames", "&Use SSL" ]
        bcodes = %w[ HTTP, FRAMES, SSL ]
        butts.each_with_index do |t, i|
          item RubyCurses::CheckBox.new nil, 
            :text => butts[i],
            :variable => $config_hash,
            :name => bcodes[i],
            :row => r+i,
            :col => 5
        end
      end
      tp.add_tab "&Editors" do
        butts = %w[ &Vim E&macs &Jed &Other ]
        bcodes = %w[ VIM EMACS JED OTHER]
        row = 2
        butts.each_with_index do |name, i|
          item RubyCurses::CheckBox.new nil ,
            :text => name,
            :variable => $config_hash,
            :name => bcodes[i],
            :row => row+i,
            :col => 5
        end
      end
      help = "q to quit. <TAB> through tabs, Space or Enter to select Tab."
      RubyCurses::Label.new @form, {:text => help, :row => 1, :col => 2, :color => :yellow}
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        @form.handle_key(ch)
        @window.wrefresh
      end
  end
end
if $0 == __FILE__
  # Initialize curses
  begin
    # XXX update with new color and kb
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("rbc13.log")
    $log.level = Logger::DEBUG
    n = TestTabbedPane.new
    n.run
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
