require 'rbcurse'
##
module RubyCurses
  class Link < Button
    dsl_property :description


    def initialize form, config={}, &block
      super
      @text_offset = 0
      # haha we've never done this, pin the cursor up on 0,0
      @col_offset = -1 
      # this won't be triggered since the shortcut does not set menmo
      # unless form is there.
      # Sometimes the mnemonic is not in text, such as '?'
      if @mnemonic
        form.bind_key(@mnemonic.downcase, self){ self.fire }
      end
      @display_length = config[:width]
    end
    def fire
      super
      self.focus
    end
    def getvalue_for_paint
      getvalue()
    end
    ##
  end # class
end # module
