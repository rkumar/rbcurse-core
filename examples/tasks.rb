require 'rbcurse/core/util/app'
require 'rbcurse/core/widgets/rlist'

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Task List", :text_right =>"New Improved!"

  message "Press F10 or qq to escape from here"

  file = "data/todo.txt"
  alist = File.open(file,'r').readlines if File.exists? file
  #flow :margin_top => 1, :item_width => 50 , :height => FFI::NCurses.LINES-2 do
  stack :margin_top => 1, :width => :expand, :height => FFI::NCurses.LINES-2 do

    task = field :label => "    Task:", :display_length => 50, :maxlen => 80, :bgcolor => :cyan, :color => :black
    pri = field :label => "Priority:", :display_length => 1, :maxlen => 1, :type => :integer, 
      :valid_range => 1..9, :bgcolor => :cyan, :color => :black , :default => "5"
    pri.overwrite_mode = true
    # u,se voerwrite mode for this TODO and catch exception

    flow do
      button :text => "&Save" do
        w = @form.by_name["tasklist"]
        w << "#{pri.text}. #{task.text}" 
      end
      button :text => "&Clear"
    end
    lb = listbox :list => alist, :title => "[ todos ]", :height_pc => 80, :name => "tasklist"
  end
    #label({:text => "checking overwrite from list", :row => 10, :col => 60})
    #label({:text => "checking overwrite from list 1", :row => 11, :col => 60})
  label({:text => "Press F4 and F5 to test popup, space or enter to select", :row => Ncurses.LINES-1, :col => 0})

  @form.bind_key(FFI::NCurses::KEY_F4) { row = lb.current_index+lb.row; col=lb.col+lb.current_value.length+1;  ret = popuplist(%w[ andy berlioz strauss tchaiko matz beethoven], :row => row, :col => col, :title => "Names", :bgcolor => :blue, :color => :white) ; alert "got #{ret} "}
  @form.bind_key(FFI::NCurses::KEY_F5) {  list = %x[ls].split("\n");ret = popuplist(list, :title => "Files"); alert "Got #{ret} #{list[ret]} " }

  @window.confirm_close_command do
    confirm "Sure you wanna quit?"
  end
  @window.close_command do
    w = @form.by_name["tasklist"]
    File.open(file, 'w') {|f| 
      w.list.each { |e|  
        f.puts(e) 
      } 
    } 
  end
  
end # app
