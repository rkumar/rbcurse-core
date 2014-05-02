# ----------------------------------------------------------------------------- #
#         File: testprogress.rb
#  Description: a test program for progress bar widget
#     creates two progress bars, one old style and one new
#     Keeps running till 'q' pressed.
#       Author: rkumar http://github.com/rkumar/rbcurse-core/
#         Date: 2014-03-27 - 23:31
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2014-03-27 23:44
# ----------------------------------------------------------------------------- #
#  testprogress.rb  Copyright (C) 2012-2014 rahul kumar
require 'logger'
require 'rbcurse'
require 'rbcurse/core/widgets/rprogress'
if $0 == __FILE__

  #include RubyCurses

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    path = File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")
    file   = File.open(path, File::WRONLY|File::TRUNC|File::CREAT) 
    $log = Logger.new(path)
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      @form = Form.new @window
      title = (" "*30) + "Demo of Progress Bar (q quits, s - slow down) " + Rbcurse::VERSION
      Label.new @form, {:text => title, :row => 1, :col => 0, :color => :green, :bgcolor => :black}
      Label.new @form, {:text => "Press q to quit, s/f make slow or fast", :row => 10, :col => 10}
      Label.new @form, {:text => "Old style and modern style progress bars", :row => 12, :col => 10}
      r = 14; fc = 12;

      pbar1 = Progress.new @form, {:width => 20, :row => r, :col => fc, 
        :name => "pbar1", :style => :old}
        #:bgcolor => :white, :color => 'red', :name => "pbar1", :style => :old}
      pbar = Progress.new @form, {:width => 20, :row => r+2, :col => fc, 
        :bgcolor => :white, :color => :red, :name => "pbar"}
      
      pbar.visible false
      pb =  @form.by_name["pbar"]
      pb.visible true
      len = 1 
      ct = (100) * 1.00
      pb.fraction(len/ct)
      pbar1.fraction(len/ct)
      i = ((len/ct)*100).to_i
      i = 100 if i > 100
      pb.text = "completed:#{i}"


      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels

      # the main loop

      # this is so there's no wait for a key, i want demo to proceed without key press, but
      # respond if there is one
      Ncurses::nodelay(@window.get_window, bf = true)
     
      # sleep seconds between refresh of progress
      slp = 0.1
      ##while((ch = @window.getchar()) != FFI::NCurses::KEY_F10 )
        #break if ch == ?\C-q.getbyte(0)
      while((ch = @window.getch()) != 27)
        break if ch == "q".ord
        ## slow down
        if ch == "s".ord
          slp *= 2
        elsif ch == "f".ord
          ## make faster
          slp /= 2.0
        end
        begin

          sleep(slp)
          len += 1
          if len > 100
            len = 1
            sleep(1.0)
          end
          ct = (100) * 1.00
          pb.fraction(len/ct)
          pbar1.fraction(len/ct)
          i = ((len/ct)*100).to_i
          i = 100 if i > 100
          pb.text = "completed:#{i}"

          #@form.handle_key(ch)
          @form.repaint
          @window.wrefresh
          Ncurses::Panel.update_panels
          #end

        rescue => err
          break
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
