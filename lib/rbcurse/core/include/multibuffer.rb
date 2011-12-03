module RubyCurses
  # this module makes it possible for a textview to maintain multiple buffers
  # The first buffer has been placed using set_content(lines, config). 
  # After this, additional buffers mst be supplied with add_content text, config.
  # Also, please note that after you call set_content the first time, you must call 
  # add_content so the buffer can be accessed while cycling. will try to fix this.
  # (I don't want to touch textview, would prefer not to write a decorator).

  # TODO allow setting of a limit, so in some cases where we keep adding
  # programatically, the 
  module MultiBuffers
    extend self

    # add content to buffers of a textview
    # @param [Array] text
    # @param [Hash] options, typically :content_type => :ansi or :tmux
    def add_content text, config={}
      unless @_buffers
        bind_key(?\M-n, :buffer_next)
        bind_key(?\M-p, :buffer_prev)
        bind_key(KEY_BACKSPACE, :buffer_prev) # backspace, already hardcoded in textview !
        bind_key(?:, :buffer_menu)
      end
      @_buffers ||= []
      @_buffers_conf ||= []
      @_buffers << text
      @_buffers_conf << config
      @_buffer_ctr ||= 0
      $log.debug "XXX:  HELP adding text #{@_buffers.size} "
    end

    # display next buffer
    def buffer_next
      @_buffer_ctr += 1
      x = @_buffer_ctr
      l = @_buffers[x]
      @_buffer_ctr = 0 unless l
      set_content @_buffers[@_buffer_ctr], @_buffers_conf[@_buffer_ctr]
    end
    #
    # display previous buffer if any
    def buffer_prev
      if @_buffer_ctr < 1
        buffer_last
        return
      end
      @_buffer_ctr -= 1 if @_buffer_ctr > 0
      x = @_buffer_ctr
      l = @_buffers[x]
      if l
        set_content l, @_buffers_conf[x]
      end
    end
    def buffer_last
      @_buffer_ctr = @_buffers.count - 1
      l = @_buffers.last
      set_content l, @_buffers_conf.last
    end
    # close window, a bit clever
    def close
      @graphic.ungetch(?q.ord)
    end
    # display a menu so user can do buffer management
    # However, how can application add to these. Or disable, such as when we 
    # add buffer delete or buffer insert or edit
    def buffer_menu
      menu = PromptMenu.new self do
        item :n, :buffer_next
        item :p, :buffer_prev
        item :b, :scroll_backward
        item :f, :scroll_forward
        item :q, :close
        submenu :m, "submenu..." do
          item :p, :goto_last_position
          item :r, :scroll_right
          item :l, :scroll_left
        end
      end
      menu.display_new :title => "Buffer Menu"
    end

  end
end
