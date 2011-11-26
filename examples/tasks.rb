require 'rbcurse/core/util/app'
require 'rbcurse/core/widgets/rlist'

App.new do 
  @default_prefix = " "
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Task List", :text_right =>"New Improved!"

  message "Press F10 or qq to escape from here"

  file = "data/todo.txt"
  alist = File.open(file,'r').readlines if File.exists? file
  #flow :margin_top => 1, :item_width => 50 , :height => FFI::NCurses.LINES-2 do
  stack :margin_top => 1, :width => :expand, :height => FFI::NCurses.LINES-4 do

    #task = field :label => "    Task:", :display_length => 50, :maxlen => 80, :bgcolor => :cyan, :color => :black
    #pri = field :label => "Priority:", :display_length => 1, :maxlen => 1, :type => :integer, 
      #:valid_range => 1..9, :bgcolor => :cyan, :color => :black , :default => "5"
    #pri.overwrite_mode = true
    # u,se voerwrite mode for this TODO and catch exception

    lb = listbox :list => alist.sort, :title => "[ todos ]", :height_pc => 100, :name => "tasklist"
    lb.bind_key(?d){ 
      if confirm("Delete #{lb.current_value} ?")
        lb.delete_at lb.current_index 
        # TODO reposition cursor at 0. use list_data_changed ?
      end
    }
    lb.bind_key(?e){ 
      if ((value = get_string("Edit Task:", :width => 80, :default => lb.current_value, :maxlen => 80, :display_length => 70)) != nil)
        lb[lb.current_index]=value
      end
    }
    lb.bind_key(?A){ 

      # ADD
    task = Field.new :label => "    Task:", :display_length => 70, :maxlen => 80, :bgcolor => :cyan, :color => :black,
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
      val =  @default_prefix + tp.form.by_name['pri'].text + ". " + tp.form.by_name['task'].text 
      w = @form.by_name["tasklist"]
      _l = w.list
      _l << val
      w.list(_l.sort)
    else # CANCEL
      #return nil
    end
    }
    # decrease priority
    lb.bind_key(?D){ 
      line = lb.current_value
      p = line[1,1].to_i
      if p < 9
        p += 1 
        line[l,1] = p.to_s
        lb[lb.current_index]=line
        lb.list(lb.list.sort)
      end
    }
    # increase priority
    lb.bind_key(?I){ 
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
    lb.bind_key(?x){ 
      line = lb.current_value
      line[0,1] = "x"
      lb[lb.current_index]=line
      lb.list(lb.list.sort)
    }
    # flag task with a single character
    lb.bind_key(?!){ 
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
  end # stack
  s = status_line

    keyarray = [
      ["F1" , "Help"], ["F10" , "Exit"], 
      ["F2", "Menu"], ["F4", "View"],
      ["d", "delete item"], ["e", "edit item"],
      ["A", "add item"], ["x", "close item"],
      ["I", "inc priority"], ["D", "dec priority"],

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
