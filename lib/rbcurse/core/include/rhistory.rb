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
    # pass the array of history values
    def history arr
      return @history unless arr
      @history = arr 
      $history_key ||= ?\M-h
      # ensure that the field is not overriding this in handle_key
      bind_key($history_key) { _show_history }
      # widget should have CHANGED event, or this will either give error, or just not work
      # else please update history whenever you want a value to be retrieved
      bind(:CHANGED) { @history << @text unless @history.include? @text }
    end
    
    # pass in some configuration for histroy such as row and column to show popup on
    def history_config config={}
      @_history_config = config
    end

    # popup the hist 
    # 
    private
    def _show_history
      return unless @history
      list = @history
      # calculate r and c
      c = @_history_config[:col] || @col # this is also dependent on window coords, as in a status_window or messagebox
      r = @row - 10
      if @row < 10
        r = @row + 1
      end
      r = @_history_config[:row] || r
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
