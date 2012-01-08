require 'rbcurse/core/util/app'
require 'rbcurse/core/widgets/rlist'

# a simple example of how to get colored row rendering.
# also see rfe.rb for a more complete example
class CellRenderer
  attr_accessor :display_length
  def repaint g, r, c, crow, content, focus_type, selected
    color = $datacolor
    att = NORMAL
    att = REVERSE if selected
    color = get_color($datacolor, :yellow, :red) if content =~ /^.1/
    color = get_color($datacolor, :red, :blue) if content =~ /^.2/
    color = get_color($datacolor, :white, :black) if content =~ /^.3/
    color = get_color($datacolor, :green, :black) if content =~ /^.4/
    color = get_color($datacolor, :red, :black) if content =~ /^.5/
    color = get_color($datacolor, :cyan, :black) if content =~ /^.6/
    color = get_color($datacolor, :magenta, :black) if content =~ /^.[7-9]/
    color = get_color($datacolor, :blue, :black) if content =~ /^x/
    g.wattron(Ncurses.COLOR_PAIR(color) | att)
    g.mvwprintw(r, c, "%s", :string, content);
    g.wattroff(Ncurses.COLOR_PAIR(color) | att)
  end
end
App.new do 
def resize
  tab = @form.by_name["tasklist"]
  cols = Ncurses.COLS
  rows = Ncurses.LINES
  tab.width_pc ||= (1.0*tab.width / $orig_cols)
  tab.height_pc ||= (1.0*tab.height / $orig_rows)
  tab.height = (tab.height_pc * rows).floor
  tab.width = (tab.width_pc * cols).floor
  #$log.debug "XXX:  RESIZE h w #{tab.height} , #{tab.width} "
end
  @default_prefix = " "
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Task List", :text_right =>"New Improved!"

  message "Press F10 or qq to quit "

  file = "data/todo.txt"
  alist = File.open(file,'r').readlines if File.exists? file
  #flow :margin_top => 1, :item_width => 50 , :height => FFI::NCurses.LINES-2 do
  #stack :margin_top => 1, :width => :expand, :height => FFI::NCurses.LINES-4 do

    #task = field :label => "    Task:", :display_length => 50, :maxlen => 80, :bgcolor => :cyan, :color => :black
    #pri = field :label => "Priority:", :display_length => 1, :maxlen => 1, :type => :integer, 
      #:valid_range => 1..9, :bgcolor => :cyan, :color => :black , :default => "5"
    #pri.overwrite_mode = true
    # u,se voerwrite mode for this TODO and catch exception

    lb = listbox :list => alist.sort, :title => "[ todos ]", :name => "tasklist", :row => 1, :height => Ncurses.LINES-4, :width => Ncurses.COLS-1
    lb.should_show_focus = false
    lb.cell_renderer CellRenderer.new
    lb.bind_key(?d, "Delete Row"){ 
      if confirm("Delete #{lb.current_value} ?")
        lb.delete_at lb.current_index 
        # TODO reposition cursor at 0. use list_data_changed ?
      end
    }
    lb.bind_key(?e, "Edit Row"){ 
      if ((value = get_string("Edit Task:", :width => 80, :default => lb.current_value, :maxlen => 80, :display_length => 70)) != nil)

        lb[lb.current_index]=value
      end
    }
    lb.bind_key(?a, "Add Record"){ 

      # ADD
    task = Field.new :label => "    Task:", :display_length => 60, :maxlen => 80, :bgcolor => :cyan, :color => :black,
    :name => 'task'
    pri = Field.new :label => "Priority:", :display_length => 1, :maxlen => 1, :type => :integer, 
      :valid_range => 1..9, :bgcolor => :cyan, :color => :black , :default => "5", :name => 'pri'
    pri.overwrite_mode = true
    config = {}
    config[:width] = 80
    config[:title] =  "New Task"
    tp = MessageBox.new config do
      item task
      item pri
      button_type :ok_cancel
      default_button 0
    end
    index = tp.run
    if index == 0 # OK
      # when does this memory get released ??? XXX 
      _t = tp.form.by_name['pri'].text 
      if _t != ""
        val =  @default_prefix + tp.form.by_name['pri'].text + ". " + tp.form.by_name['task'].text 
        w = @form.by_name["tasklist"]
        _l = w.list
        _l << val
        w.list(_l.sort)
      end
    else # CANCEL
      #return nil
    end
    }
    # decrease priority
    lb.bind_key(?-, 'decrease priority'){ 
      line = lb.current_value
      p = line[1,1].to_i
      if p < 9
        p += 1 
        line[1,1] = p.to_s
        lb[lb.current_index]=line
        lb.list(lb.list.sort)
      end
    }
    # increase priority
    lb.bind_key(?+, 'increase priority'){ 
      line = lb.current_value
      p = line[1,1].to_i
      if p > 1
        p -= 1 
        line[1,1] = p.to_s
        lb[lb.current_index]=line
        lb.list(lb.list.sort)
        # how to get the new row of that item and position it there. so one
        # can do consecutive increases or decreases
        # cursor on old row, but current has become zero. FIXME
        # Maybe setform_row needs to be called
      end
    }
    # mark as done
    lb.bind_key(?x, 'mark done'){ 
      line = lb.current_value
      line[0,1] = "x"
      lb[lb.current_index]=line
      lb.list(lb.list.sort)
    }
    # flag task with a single character
    lb.bind_key(?!, 'flag'){ 
      line = lb.current_value.chomp
      value = get_string("Flag for #{line}. Enter one character.", :maxlen => 1, :display_length => 1)
      #if ((value = get_string("Edit Task:", :width => 80, :default => lb.current_value)) != nil)
        #lb[lb.current_index]=value
      #end
      if value ##&& value[0,1] != " "
        line[0,1] = value[0,1]
        lb[lb.current_index]=line
        lb.list(lb.list.sort)
      end
    }
  #end # stack
  s = status_line
  @form.bind(:RESIZE) {  resize }

    keyarray = [
      ["F1" , "Help"], ["F10" , "Exit"], 
      ["F2", "Menu"], ["F4", "View"],
      ["d", "delete item"], ["e", "edit item"],
      ["a", "add item"], ["x", "close item"],
      ["+", "inc priority"], ["-", "dec priority"],

      ["M-x", "Command"], nil
    ]

    gw = get_color($reversecolor, 'green', 'black')
    @adock = dock keyarray, { :row => Ncurses.LINES-2, :footer_color_pair => $datacolor, 
      :footer_mnemonic_color_pair => gw }

  @window.confirm_close_command do
    confirm "Sure you wanna quit?", :default_button => 1
  end
  @window.close_command do
    w = @form.by_name["tasklist"]
    if confirm("Save tasks?", :default_button => 0)
      system("cp #{file} #{file}.bak")
      File.open(file, 'w') {|f| 
        w.list.each { |e|  
          f.puts(e) 
        } 
      } 
    end
  end
  
end # app
