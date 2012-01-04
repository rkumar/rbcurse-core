# ----------------------------------------------------------------------------- #
#         File: actionmanager.rb
#  Description: a class that manages actions for a widget
#
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-01-4 
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: ,,L
# ----------------------------------------------------------------------------- #
#
# Maintains actions for a widget
module RubyCurses
  class ActionManager
    attr_reader :actions

    def initialize #form, config={}, &block
      @actions = []
       #instance_eval &block if block_given?
    end
    def add_action act
      @actions << act
    end
    def remove_action act
      @actions.remove act
    end
    #
    # insert an item at given position (index)
    def insert_action pos, *val
      @actions[pos] = val
    end
    #def create_menuitem *args
      #PromptMenu.create_menuitem *args
    #end

    # popup the hist 
    # 
    def show_actions
      return if @actions.empty?
      list = @actions
      menu = PromptMenu.new self do |m|
      list.each { |e| 
        m.add *e
      }
      end
      menu.display_new :title => 'Widget Menu (Press letter)'
    end
  end # class
end # mod RubyC
