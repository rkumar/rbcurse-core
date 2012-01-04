# ----------------------------------------------------------------------------- #
#         File: listbindings.rb
#  Description: bindings for multi-row widgets such as listbox, table, textview
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2011-12-11 - 12:58
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2011-12-11 - 12:59
# ----------------------------------------------------------------------------- #
#
module RubyCurses
  # 
  #  bindings for multi-row widgets such as listbox, table, textview
  # 
  module ListBindings
    extend self
    def bindings
    $log.debug "XXX:  INSIDE LISTBINDING FOR #{self.class} "
      bind_key(Ncurses::KEY_LEFT, 'cursor backward'){ cursor_backward } if respond_to? :cursor_backward
      bind_key(Ncurses::KEY_RIGHT, 'cursor_forward'){ cursor_forward } if respond_to? :cursor_forward
      # very irritating when user pressed up arrow, commented off 2012-01-4  can be made optional
      bind_key(Ncurses::KEY_UP, 'previous row'){ ret = up;  } #get_window.ungetch(KEY_BTAB) if ret == :NO_PREVIOUS_ROW }
      # the next was irritating if user wanted to add a row ! 2011-10-10 
      #bind_key(Ncurses::KEY_DOWN){ ret = down ; get_window.ungetch(KEY_TAB) if ret == :NO_NEXT_ROW }
      bind_key(Ncurses::KEY_DOWN, 'next row'){ ret = down ; }

      # this allows us to set on a component basis, or global basis
      # Motivation was mainly for textarea which needs emacs keys
      kmap = @key_map || $key_map || :both
      if kmap == :emacs || kmap == :both
        bind_key(?\C-v, 'scroll forward'){ scroll_forward }
        # clashes with M-v for toggle one key selection, i guess you can set it as you like
        bind_key(?\M-v, 'scroll backward'){ scroll_backward }
        bind_key(?\C-s, 'ask search'){ ask_search() }
        bind_key(?\C-n, 'next row'){ next_row() }
        bind_key(?\C-p, 'previous row'){ previous_row() }
        bind_key(?\M->, 'goto bottom'){ goto_bottom() }
        bind_key(?\M-<, 'goto top'){ goto_top() }
        bind_key([?\C-x, ?>], :scroll_right)
        bind_key([?\C-x, ?<], :scroll_left)
      end
      if kmap == :vim || kmap == :both
        # some of these will not have effect in textarea such as j k, gg and G, search
        bind_key(?j, 'next row'){ next_row() }
        bind_key(?k, 'previous row'){ previous_row() }
        bind_key(?\C-d, 'scroll forward'){ scroll_forward() }
        bind_key(?\C-b, 'scroll backward'){ scroll_backward() }
        bind_key([?g,?g], 'goto start'){ goto_start } # mapping double keys like vim
        bind_key(?G, 'goto end'){ goto_bottom() }
        bind_key([?',?'], 'goto last position'){ goto_last_position } # vim , goto last row position (not column)

        bind_key(?/, :ask_search)
        bind_key(?n, :find_more)
        bind_key(?h, 'cursor backward'){ cursor_backward }  if respond_to? :cursor_backward
        bind_key(?l, 'cursor forward'){ cursor_forward } if respond_to? :cursor_forward
      end
      bind_key(?\C-a, 'start of line'){ cursor_bol } if respond_to? :cursor_bol
      bind_key(?\C-e, 'end of line'){ cursor_eol } if respond_to? :cursor_eol
      bind_key(?\M-l, :scroll_right)
      bind_key(?\M-h, :scroll_left)

      # save as and edit_external are only in textview and textarea
      # save_as can be given to list's also and tables
      # put them someplace so the code can be shared.
      bind_key([?\C-x, ?\C-s], :saveas)
      bind_key([?\C-x, ?e], :edit_external)
      
      # textview also uses space for scroll_forward
    end # def
  end
end
include RubyCurses::ListBindings
