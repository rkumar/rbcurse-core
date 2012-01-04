# ----------------------------------------------------------------------------- #
#         File: action.rb
#  Description: A common action class which can be used with buttons, popupmenu
#               and anythign else that takes an action or command
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: been around since the beginning
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: use ,,L
#  NOTE: I don't like the dependence on rwidget and EventHandler. Seems it needs
#   that only for fire_handler and not sure if that's used. I've not bound :FIRE
#   ever.
#
#   Darn, do i really need to have dsl_accessors and property This is not a 
#   widget and there's no repaint. Do button's and popups really repaint
#   themselves when a dsl_property is modified ?
# ----------------------------------------------------------------------------- #
#
require 'rbcurse/core/widgets/rwidget'
include RubyCurses
module RubyCurses
  ## encapsulates behaviour allowing centralization
  # == Example
  #    a = Action.new("&New Row") { commands }
  #    a.accelerator "Alt N"
  #    menu.add(a)
  #    b = Button.new form do
  #      action a
  #      ...
  #    end
  class Action < Proc
    include EventHandler # removed 2012-01-3 maybe you can bind FIRE
    #include ConfigSetup # removed 2012-01-3 
    # name used on button or menu
    dsl_property :name
    dsl_property :enabled
    dsl_accessor :tooltip_text
    dsl_accessor :help_text
    dsl_accessor :mnemonic
    dsl_accessor :accelerator

    def initialize name, config={}, &block
      super &block
      @name = name
      @name.freeze
      @enabled = true
      # removing dependency from config
      #config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      @config = config
      keys = @config.keys
      keys.each do |e| 
        variable_set(e, @config[e])
      end
      @_events = [:FIRE]
    end
    def call
      return unless @enabled
      # seems to be here, if you've bound :FIRE no this, not on any widget
      fire_handler :FIRE, self  
      super
    end
    # the next 3 are to adapt this to CMenuitems
    def hotkey
      return @mnemonic if @mnemonic
      ix = @name.index('&')
      if ix
        return @name[ix+1, 1].downcase
      end
    end
    # to adapt this to CMenuitems
    def label
      @name.sub('&','')
    end
    # to adapt this to CMenuitems
    def action
      self
    end

  end # class
end # module

