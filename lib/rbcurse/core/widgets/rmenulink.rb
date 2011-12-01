require 'rbcurse/core/widgets/rlink'
##
module RubyCurses
  class MenuLink < Link
    dsl_property :description

    def initialize form, config={}, &block
      config[:hotkey] = true
      super
      @col_offset = -1 * (@col || 1)
      @row_offset = -1 * (@row || 1)
    end
    # added for some standardization 2010-09-07 20:28 
    # alias :text :getvalue # NEXT VERSION
    # change existing text to label

    def getvalue_for_paint
      "%s      %-12s   -    %-s" % [ @mnemonic , getvalue(), @description ]
    end
    ##
  end # class
end # module
