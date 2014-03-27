require 'logger'
require 'rbcurse'
require 'rbcurse/core/widgets/rcombo'
require 'rbcurse/core/include/appmethods.rb'
def help_text
      <<-eos
               COMBO  HELP 

      This is some help text for Combos

      You may press SPACE to invoke the popup and then use arrow keys to traverse. (j and k may also work)
      SPACE on the popup to select.

      You may press the first character of the desired item to see all those items starting with that char.
      e.g. pressing "v" will cycle through vt100 and vt102


      If the arrow_key_policy is set to :popup then a down arrow will also invoke popup. However, if you
      prefer the down arrow to go to the next field, use :ignore. In that case, only SPACE can trigger POPUP.

      -----------------------------------------------------------------------
      eos
end
if $0 == __FILE__

  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    path = File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")
    file   = File.open(path, File::WRONLY|File::TRUNC|File::CREAT) 
    $log = Logger.new(path)
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors testcombo.rb --------- #{@window} "
      @form = Form.new @window
      title = (" "*30) + "Demo of Combo (F10 quits, F1 help, SPACE to popup combo) " + Rbcurse::VERSION
      Label.new @form, {:text => title, :row => 1, :col => 0, :color => :green, :bgcolor => :black}
      r = 3; fc = 12;



        cb = ComboBox.new @form, :row => 7, :col => 2, :display_length => 20, 
          :list => %w[xterm xterm-color xterm-256color screen vt100 vt102],
          :arrow_key_policy => :popup,
          :label => "Declare terminal as: "

      # arrow_key_policy can be popup or ignore
        # display_length is used to place combo symbol and popup and should be calculated
        # from label.text

      @form.help_manager.help_text = help_text
      #@form.bind_key(FFI::NCurses::KEY_F1, 'help') {  display_app_help help_text() }
      @form.bind_key(FFI::NCurses::KEY_F1, 'help') {  display_app_help }
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels

      # the main loop

      while((ch = @window.getchar()) != FFI::NCurses::KEY_F10 )
        break if ch == ?\C-q.getbyte(0)
        begin
          @form.handle_key(ch)

        rescue => err
          $log.error( err) if err
          $log.error(err.backtrace.join("\n")) if err
          textdialog err
          $error_message.value = ""
        end

        # this should be avoided, we should not muffle the exception and set a variable
        # However, we have been doing that
        if $error_message.get_value != ""
          alert($error_message, {:bgcolor => :red, 'color' => 'yellow'}) if $error_message.get_value != ""
          $error_message.value = ""
        end

        @window.wrefresh
      end # while loop
    end # catch
  rescue => ex
  ensure
    $log.debug " -==== EXCEPTION =====-"
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
    @window.destroy if !@window.nil?
    VER::stop_ncurses
    puts ex if ex
    puts(ex.backtrace.join("\n")) if ex
  end
end
