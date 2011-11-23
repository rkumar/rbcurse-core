# ------------------------------------------------------------ #
#         File: widgetshortcuts.rb 
#  Description: A common module for shortcuts to create widgets
#               Also, stacks and flows objects
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 05.11.11 - 15:13 
#  Last update: 2011-11-21 - 19:28
#
#  I hope this slowly does not become an unmaintainable maze like vimsplit
#
#      "Simplicity hinges as much on cutting nonessential features as on adding helpful ones."
#      - Walter Bender
#
#  == TODO
#     add multirow comps like textview and textarea, list
#     add blocks that make sense like in app
#     - what if user does not want form attached - app uses useform ot
#       to check for this, if current_object don't add form
#
#     - usage of _position inside means these shortcuts cannot be reused
#     with other positioning systems, we'll be cut-pasting forever
#
#  == CHANGES
# ------------------------------------------------------------ #
#

# what is the real purpose of the shortcuts, is it to avoid putting nil
# for form there if not required.
# Or is it positioning, such as in a stack. or just a method ?
require 'rbcurse/core/widgets/rlist'
require 'rbcurse/core/widgets/rtextview'
module RubyCurses
  module WidgetShortcuts
    class Ws
      attr_reader :config
      def initialize config={}
        @config = config
      end
      def [](sym)
        @config[sym]
      end
      def []=(sym, val)
        @config[sym] = val
      end
    end
    class WsStack < Ws; end
    class WsFlow < Ws; end
    def widget_shortcuts_init
      @_ws_app_row = @_ws_app_col = 0
      #@_ws_active = []
      @_ws_active = nil # so we can use shortcuts if no stack used
      @_ws_components = []
      @variables = {}
    end
    def blank
      label :text => ""
    end
    def line config={}
      #horizontal line TODO
      #row = config[:row] || @app_row
      #width = config[:width] || 20
      #_position config
      #col = config[:col] || 1
      #@color_pair = config[:color_pair] || $datacolor
      #@attrib = config[:attrib] || Ncurses::A_NORMAL
      #@window.attron(Ncurses.COLOR_PAIR(@color_pair) | @attrib)
      #@window.mvwhline( row, col, FFI::NCurses::ACS_HLINE, width)
      #@window.attron(Ncurses.COLOR_PAIR(@color_pair) | @attrib)
    end
    def radio config={}, &block
      a = config[:group]
      # should we not check for a nil
      if @variables.has_key? a
        v = @variables[a]
      else
        v = Variable.new
        @variables[a] = v
      end
      config[:variable] = v
      config.delete(:group)
      w = RadioButton.new nil, config #, &block
      _position w
      if block
        w.bind(:PRESS, &block)
      end
      return w
    end
    # create a shortcut for a class
    # path is path of file to use in require starting with rbcurse
    # klass is name of class to instantiate
  def self.def_widget(path, klass, short=nil)
    p=""
     if path
      p="require \"#{path}\""
    end
     short ||= klass.downcase
      eval %{
        def #{short}(config={}, &block)
          #{p}
          w = #{klass}.new nil, config
          _position w
          w.command &block if block_given?
          return w
        end
      }
  end
  def_widget "rbcurse/core/widgets/rprogress", "Progress"
  def_widget "rbcurse/core/widgets/scrollbar", "Scrollbar"
  def_widget nil, "Label"
  def_widget nil, "Field"
  def_widget nil, :CheckBox, 'check'
  def_widget nil, :Button
  def_widget nil, :ToggleButton, 'toggle'
    def menubar &block
      require 'rbcurse/core/widgets/rmenu'
      RubyCurses::MenuBar.new &block
    end
    def app_header title, config={}, &block
      require 'rbcurse/core/widgets/applicationheader'
      header = ApplicationHeader.new @form, title, config, &block
    end
    # editable text area
    def textarea config={}, &block
      require 'rbcurse/core/widgets/rtextarea'
      # TODO confirm events many more
      events = [ :CHANGE,  :LEAVE, :ENTER ]
      block_event = events[0]
      #_process_args args, config, block_event, events
      #config[:width] = config[:display_length] unless config.has_key? :width
      # if no width given, expand to flows width
      #config[:width] ||= @stack.last.width if @stack.last
      useform = nil
      #useform = @form if @current_object.empty?
      w = TextArea.new useform, config
      w.width = :expand unless w.width
      w.height ||= :expand # TODO This has to come before other in stack next one will overwrite.
      _position(w)
      w.height ||= 8 # TODO
      # need to expand to stack's width or flows itemwidth if given
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    def textview config={}, &block
      events = [ :LEAVE, :ENTER ]
      block_event = events[0]
      #_process_args args, config, block_event, events
      #config[:width] = config[:display_length] unless config.has_key? :width
      # if no width given, expand to flows width
      #config[:width] ||= @stack.last.width if @stack.last
      useform = nil
      #useform = @form if @current_object.empty?
      w = TextView.new useform, config
      w.width = :expand unless w.width
      w.height ||= :expand # TODO This has to come before other in stack next one will overwrite.
      _position(w)
      # need to expand to stack's width or flows itemwidth if given
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    def listbox config={}, &block
      events = [ :PRESS, :ENTER_ROW, :LEAVE, :ENTER ]
      block_event = events[0]
      #_process_args args, config, block_event, events
      #config[:width] = config[:display_length] unless config.has_key? :width
      # if no width given, expand to flows width
      #config[:width] ||= @stack.last.width if @stack.last
      useform = nil
      #useform = @form if @current_object.empty?
      w = List.new useform, config
      w.width = :expand unless w.width
      w.height ||= :expand # TODO We may need to push this before _position so it can be accounted for in stack
      _position(w)
      # need to expand to stack's width or flows itemwidth if given
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    # prints pine-like key labels
    def dock labels, config={}, &block
      require 'rbcurse/core/widgets/keylabelprinter'
      klp = RubyCurses::KeyLabelPrinter.new @form, labels, config, &block
    end

    def link config={}, &block
      require 'rbcurse/extras/widgets/rlink'
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _position(w)
      config[:highlight_foreground] = "yellow"
      config[:highlight_background] = "red"
      toggle = Link.new @form, config
      if block
        toggle.bind(block_event, toggle, &block)
      end
      return toggle
    end
    def menulink config={}, &block
      require 'rbcurse/extras/widgets/rmenulink'
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _position(w)
      config[:highlight_foreground] = "yellow"
      config[:highlight_background] = "red"
      toggle = MenuLink.new @form, config
      if block
        toggle.bind(block_event, toggle, &block)
      end
      return toggle
    end
    def tree config={}, &block
      require 'rbcurse/core/widgets/rtree'
      events = [:TREE_WILL_EXPAND_EVENT, :TREE_EXPANDED_EVENT, :TREE_SELECTION_EVENT, :PROPERTY_CHANGE, :LEAVE, :ENTER ]
      block_event = nil
      config[:height] ||= 10
      # if no width given, expand to flows width
      useform = nil
      #useform = @form if @current_object.empty?
      w = Tree.new useform, config, &block
      w.width ||= :expand 
      w.height ||= :expand # TODO This has to come before other in stack next one will overwrite.
      _position w
      return w
    end
    # creates a simple readonly table, that allows users to click on rows
    # and also on the header. Header clicking is for column-sorting.
    def tabular_widget config={}, &block
      require 'rbcurse/core/widgets/tabularwidget'
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER, :CHANGE, :ENTER_ROW, :PRESS ]
      block_event = nil
      config[:height] ||= 10 # not sure if this should be here
      _position(w)
      # if no width given, expand to stack width
      #config.delete :title
      useform = nil

      w = TabularWidget.new useform, config # NO BLOCK GIVEN
      if block_given?
        #@current_object << w
        yield_or_eval &block
        #@current_object.pop
      end
      return w
    end
    alias :table :tabular_widget
    def vimsplit config={}, &block
      require 'rbcurse/extras/widgets/rvimsplit'
      #TODO check these
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER ]
      block_event = nil
      config[:height] ||= 10
      _position(w)
      # if no width given, expand to flows width
      #config.delete :title
      useform = nil

      w = VimSplit.new useform, config # NO BLOCK GIVEN
      if block_given?
        #@current_object << w
        #instance_eval &block if block_given?
        yield w
        #@current_object.pop
      end
      return w
    end
    def _position w
      if @_ws_active.nil? || @_ws_active.empty?
        # no stack or flow, this is independent usage, or else we are outside stacks and flows
        #
        # this is outside any stack or flow, so we do the minimal
        # user should specify row and col
        w.row ||= 0
        w.col ||= 0
        #$log.debug "XXX:  LABEL #{w.row} , #{w.col} "
        w.set_form @form if @form # temporary,, only set if not inside an object FIXME
        if w.width == :expand  # calculate from current col, not 0 FIXME
          w.width = FFI::NCurses.COLS-w.col # or take windows width since this could be in a message box
        end
        if w.height == :expand
          # take from current row, and not zero  FIXME
          w.height = FFI::NCurses.LINES-w.row # or take windows width since this could be in a message box
        end
        return

      end
      # -------------------------- there is a stack or flow -------------------- #
      #
      cur = @_ws_active.last
      unless cur
        raise "This should have been handled previously.Somethings wrong, check/untested"
      end
      r = cur[:row] || 0
      c = cur[:col] || 0
      w.row = r
      w.col = c
      # if flow then take flows height, else use dummy value
      if w.height_pc
        w.height =       ( (cur[:height] * w.height_pc.to_i)/100).floor
      end
      if w.height == :expand
        if cur.is_a? WsFlow
          w.height = cur[:height] || 8 #or raise "height not known for flow"
        else
          w.height = cur[:item_height] || 8 #or raise "height not known for flow"
        end
        #alert "setting ht to #{w.height}, #{cur[:height]} , for #{cur} "
      end
      if cur.is_a? WsStack
        r += w.height || 1   # NOTE, we need to have height for this purpose defined BEFORE calling for list/text
        cur[:row] = r
      else
        wid = cur[:item_width] || w.width || 10
        c += wid + 1
        cur[:col] = c
      end
      if w.width == :expand
        if cur.is_a? WsFlow
          w.width = cur[:item_width] or raise "item_Width not known for stack #{cur.class}, #{cur[:item_width]} "
        else
          w.width = cur[:width] or raise "Width not known for stack #{cur.class}, #{cur[:width]} "
        end
      end
      #alert "set width to #{w.width} ,cur: #{cur[:width]} ,iw: #{cur[:item_width]} "
      if cur.is_a? WsFlow
        unless w.height
          w.height = cur[:height] #or raise "Height not known for flow"
        end
      end
      w.color   ||= cur[:color]
      w.bgcolor ||= cur[:bgcolor]
      w.set_form @form if @form # temporary
      @_ws_components << w
      cur[:components] << w
    end
    # make it as simple as possible, don't try to be intelligent or
    # clever, put as much on the user 
    def stack config={}, &block
      s = WsStack.new config
      @_ws_active ||= []
      _configure s
      @_ws_active << s
      yield_or_eval &block if block_given?
      @_ws_active.pop 
      
      # ---- stack is finished now
      last = @_ws_active.last
      if last 
        case last
        when WsStack
        when WsFlow
          last[:col] += last[:item_width] || 0 
          # this tries to set height of outer flow based on highest row
          # printed, however that does not account for height of object,
          # so user should give a height to the flow.
          last[:height] = s[:row] if s[:row] > (last[:height]||0)
          $log.debug "XXX: STACK setting col to #{s[:col]} "
        end
      end

    end
    #
    # item_width - width to use per item 
    #   but the item width may apply to stacks inside not to items
    def flow config={}, &block
      s = WsFlow.new config
      @_ws_active ||= []
      _configure s
      @_ws_active << s
      yield_or_eval &block if block_given?
      @_ws_active.pop 
      last = @_ws_active.last
      if last 
        case last
        when WsStack
          if s[:height]
            last[:row] += s[:height] 
          else
            #last[:row] += last[:highest_row]  
            last[:row] += 1
          end
        when WsFlow
          last[:col] += last[:item_width] || 0 
        end
      end
    end
    # flow and stack could have a border option
    # NOTE: box takes one row below too, so :expand overwrites that line
    def box config={}, &block
      require 'rbcurse/core/widgets/box'
      # take current stacks row and col
      # advance row by one and col by one
      # at end note row and advance by one
      # draw a box around using these coordinates. width should be
      # provided unless we have item width or something.
      @_ws_active ||= []
      last = @_ws_active.last
      if last
        r = last[:row]
        c = last[:col]
        config[:row] = r
        config[:col] = c
        last[:row] += config[:margin_top] || 1
        last[:col] += config[:margin_left] || 1
        _box = Box.new @form, config # needs to be created first or will overwrite area after others painted
        yield_or_eval &block if block_given?
        # FIXME last[height] needs to account for row
        h = config[:height] || last[:height] || (last[:row] - r)
        h = 2 if h < 2
        w = config[:width] || last[:width] || 15 # tmp
        case last
        when WsFlow
          w = last[:col]
        when WsStack
          #h += 1
        end
        config[:row] = r
        config[:col] = c
        config[:height] = h
        config[:width] = w
        _box.row r
        _box.col c
        _box.height h
        _box.width w
        last[:row] += 1
        last[:col] += 1 # ??? XXX if flow we need to increment properly or not ?
      end
    end

    # This configures a stack or flow not the objects inside
    def _configure s
      s[:row] ||= 0
      s[:col] ||= 0
      s[:row] += (s[:margin_top] || 0)
      s[:col] += (s[:margin_left] || 0)
      s[:width] = FFI::NCurses.COLS-s[:col] if s[:width] == :expand
      last = @_ws_active.last
      if last
        if s[:width_pc]
          if last.is_a? WsStack
            s[:width] =           (last[:width] * (s[:width_pc].to_i * 0.01)).floor
          else
            # i think this width is picked up by next stack in this flow
            last[:item_width] =   (last[:width] * (s[:width_pc].to_i* 0.01)).floor
          end
        end
        if s[:height_pc]
          if last.is_a? WsFlow
            s[:height] =       ( (last[:height] * s[:height_pc].to_i)/100).floor
          else
            # this works only for flows within stacks not for an object unless
            # you put a single object in a flow
            s[:item_height] =  ( (last[:height] * s[:height_pc].to_i)/100).floor
          end
            #alert "item height set as #{s[:height]} for #{s} "
        end
        if last.is_a? WsStack
          s[:row] += (last[:row] || 0)
          s[:col] += (last[:col] || 0)  
        else
          s[:row] += (last[:row] || 0)
          s[:col] += (last[:col] || 0)  # we are updating with item_width as each st finishes
          s[:width] ||= last[:item_width] # 
        end
      end
      s[:components] = []
    end
  end
end
