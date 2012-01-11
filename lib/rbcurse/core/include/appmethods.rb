module RubyCurses
  module Utils
    private
    def _suspend clear=true
      return unless block_given?
      Ncurses.def_prog_mode
      if clear
        Ncurses.endwin 
        # NOTE: avoid false since screen remains half off
        # too many issues
      else
        system "/bin/stty sane"
      end
      yield if block_given?
      Ncurses.reset_prog_mode
      if !clear
        # Hope we don't screw your terminal up with this constantly.
        VER::stop_ncurses
        VER::start_ncurses  
        #@form.reset_all # not required
      end
      @form.repaint if @form
      @window.wrefresh if @window
      Ncurses::Panel.update_panels
    end
    #
    # Suspends to shell so user can execute commands.
    # Maybe not be able to get your prompt correctly.
    # 
    public
    def suspend
      _suspend(false) do
        system("tput cup 26 0")
        system("tput ed")
        system("echo Enter C-d to return to application")
        system (ENV['PS1']='\s-\v\$ ') if ENV['SHELL']== '/bin/bash'
        system(ENV['SHELL']);
      end
    end

    #
    # Displays application help using either array provided
    # or checking for :help_text method
    # @param [Array] help text
    def display_app_help help_array= nil
      if help_array
        arr = help_array
      elsif respond_to? :help_text
        arr = help_text
      else
        arr = []
        arr << "    NO HELP SPECIFIED FOR APP #{self}  "
        arr << "    "
        arr << "     --- General help ---          "
        arr << "    F10         -  exit application "
        arr << "    Alt-x       -  select commands  "
        arr << "    :           -  select commands  "
        arr << "    "
      end
      case arr
      when String
        arr = arr.split("\n")
      when Array
      end
      w = arr.max_by(&:length).length

      require 'rbcurse/core/util/viewer'
      RubyCurses::Viewer.view(arr, :layout => [2, 10, [4+arr.size, 24].min, w+2],:close_key => KEY_ENTER, :title => "<Enter> to close", :print_footer => true) do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      t.attr = :reverse
      end
    end
    #
    # prompts user for unix command and displays output in viewer
    # 
    def shell_output
      $shell_history ||= []
      cmd = get_string("Enter shell command:", :maxlen => 50) do |f|
        require 'rbcurse/core/include/rhistory'
        f.extend(FieldHistory)
        f.history($shell_history)
      end
      if cmd && !cmd.empty?
        run_command cmd
        $shell_history.push(cmd) unless $shell_history.include? cmd
      end
    end

    #
    # executes given command and displays in viewer
    # @param [String] unix command, e.g., git -st
    def run_command cmd
      # http://whynotwiki.com/Ruby_/_Process_management#What_happens_to_standard_error_.28stderr.29.3F
      require 'rbcurse/core/util/viewer'
      begin
        res = `#{cmd} 2>&1`
      rescue => ex
        res = ex.to_s
        res << ex.backtrace.join("\n") 
      end
      res.gsub!("\t","   ")
      RubyCurses::Viewer.view(res.split("\n"), :close_key => KEY_ENTER, :title => "<Enter> to close, M-l M-h to scroll")
    end
    def shell_out command
      w = @window || @form.window
      w.hide
      Ncurses.endwin
      ret = system command
      Ncurses.refresh
      #Ncurses.curs_set 0  # why ?
      w.show
      return ret
    end
  end # utils
  class PrefixCommand
    attr_accessor :object
    def initialize _symbol, calling, config={}, &block
      @object = calling
      @symbol = _symbol
      @descriptions = {}
      define_prefix_command _symbol
      yield self if block_given?
    end
    def define_prefix_command _name, config={}
      $rb_prefix_map ||= {}
      #h = {}
      #@map = h
      _name = _name.to_sym unless _name.is_a? Symbol
      # TODO it may already exist, so retrieve it
      $rb_prefix_map[_name] ||= {}
      @map = $rb_prefix_map[_name]
      # create a variable by name _name
      # create a method by same name to use
      @object.instance_eval %{
        def #{_name.to_s} *args
           h = $rb_prefix_map["#{_name}".to_sym]
           raise "No prefix_map named #{_name}, #{$rb_prefix_map.keys} " unless h
           ch = @window.getchar
           if ch
              res =  h[ch]
              if res.is_a? Proc
                res.call
              else
                 send(res) if res
              end
           else
              0
           end
        end
      }
      return _name
    end
    def call
      h = @map
      ch = @object.window.getch # dicey.
        $log.debug "XXX:  CALLED #{ch} "
      if ch
        if ch == KEY_F1
          text =  ["Options are: "]
          h.keys.each { |e| c = keycode_tos(e); text << " #{c} #{@descriptions[e]} " }
          textdialog text, :title => " #{@symbol} key bindings "
          return
        end
        res =  h[ch]
        if res.is_a? Proc
          res.call
        elsif res.is_a? Symbol
          @object.send(res) if res
        else
          Ncurses.beep
          @object.window.ungetch(ch)

          :UNHANDLED
        end
      else
        raise "got nothing"
      end
    end

    # define a key within a prefix key map such as C-x
    # Now that i am moving this from global, how will describe bindings get hold of the bindings
    # and descriptions
    def define_key _keycode, *args, &blk
      _symbol = @symbol
      h = $rb_prefix_map[_symbol]
      raise ArgumentError, "No such keymap #{_symbol} defined. Use define_prefix_command." unless h
      _keycode = _keycode[0].getbyte(0) if _keycode[0].class == String
      arg = args.shift
      if arg.is_a? String
        desc = arg
        arg = args.shift
      elsif arg.is_a? Symbol
        # its a symbol
        desc = arg.to_s
      elsif arg.nil?
        desc = "unknown"
      else
        raise ArgumentError, "Don't know how to handle #{arg.class} in PrefixManager"
      end
      @descriptions[_keycode] = desc

      if !block_given?
        blk = arg
      end
      h[_keycode] = blk
    end
    alias :key :define_key
  end
end # module RubyC
include RubyCurses::Utils
