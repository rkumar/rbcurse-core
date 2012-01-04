# ----------------------------------------------------------------------------- #
#         File: rhistory.rb
#  Description: a module that pops up history, and then updates selected value
#               This goes with Field.
#               e.g.,
#               field.extend(FieldHistory)
#
#               The module name History was throwing up errors
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2011-11-27 - 18:10
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2011-11-27 - 20:11
# ----------------------------------------------------------------------------- #
#
# supply history for this object, at least give an empty array
# widget would typically be Field,
#  otherwise it should implement *text()* for getting and setting value
#  and a *CHANGED* event for when user has modified a value and moved out
# You can externally set $history_key to any unused key, otherwise it is M-h
module RubyCurses
  extend self
  module FieldHistory
    def self.extended(obj)

      obj.instance_exec {
        @history ||= []
        $history_key ||= ?\M-h
        # ensure that the field is not overriding this in handle_key
        bind_key($history_key) { _show_history }
        # widget should have CHANGED event, or this will either give error, or just not work
        # else please update history whenever you want a value to be retrieved
        bind(:CHANGED) { @history << @text if @text && (!@history.include? @text) }
      }
    end

    # pass the array of history values
    # Trying out a change where an item can also be sent in.
    # I am lost, i want the initialization to happen once.
    def history arr
      return @history unless arr
      if arr.is_a? Array
        @history = arr 
      else
        @history << arr unless @history.include? arr
      end
    end
    def history=(x); history(x); end
    
    # pass in some configuration for histroy such as row and column to show popup on
    def history_config config={}
      @_history_config = config
    end

    # popup the hist 
    # 
    private
    def _show_history
      return unless @history
      return  if @history.empty?
      list = @history
      @_history_config ||= {}
      #list = ["No history"]  if @history.empty?
      raise ArgumentError, "show_history got nil list" unless list
      # calculate r and c
      # col if fine, except for when there's a label.
      wcol = 0 # taking care of when dialog uses history 2012-01-4 
      wcol = self.form.window.left if self.form
      c = wcol + ( @field_col || @col) # this is also dependent on window coords, as in a status_window or messagebox
      sz = @history.size
      wrow = 0
      wrow = self.form.window.top if self.form
      crow = wrow + @row
      # if list can be displayed above, then fit it just above
      if crow > sz + 2
        r = crow - sz - 2
      else
        # else fit it in next row
        r = crow + 1
      end
      #r = @row - 10
      #if @row < 10
        #r = @row + 1
      #end
      r = @_history_config[:row] || r
      c = @_history_config[:col] || c
      ret = popuplist(list, :row => r, :col => c, :title  => " History ")
      if ret
        self.text = list[ret] 
        self.set_form_col 
      end
      @form.repaint if @form
      @window.wrefresh if @window
    end
  end # mod History
end # mod RubyC
