# ----------------------------------------------------------------------------- #
#         File: widgetmenu.rb
#  Description: a module that displays a menu for customization of a field
#               e.g.,
#               field.extend(WidgetMenu)
#
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2011-12-2x
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2011-12-26 - 20:25
# ----------------------------------------------------------------------------- #
#
# Provide a system for us to define a menu for customizing a widget, such that
# applicatin can also add more menuitems
module RubyCurses
  extend self
  module WidgetMenu
    include Io # added 2011-12-26 
    # add a menu item which can any one of 
    # @param key, label, desc, action | symbol
    #        key, symbol
    #        Action
    #        Action[] (maybe)
    def add_menu_item *val
      @_menuitems ||= []
      @_menuitems << val
    end
    #
    # insert an item at given position (index)
    def insert_menu_item pos, *val
      @_menuitems ||= []
      @_menuitems[pos] = val
    end
    def create_menuitem *args
      PromptMenu.create_menuitem *args
    end

    # popup the hist 
    # 
    def _show_menu
      return if @_menuitems.nil? || @_menuitems.empty?
      list = @_menuitems
      menu = PromptMenu.new self do |m|
      list.each { |e| 
        m.add *e
      }
      end
      menu.display_new :title => 'Widget Menu (Press letter)'
    end
  end # mod History
end # mod RubyC
