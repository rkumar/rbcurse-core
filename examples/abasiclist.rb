require 'rbcurse/core/util/app'
require 'rbcurse/core/widgets/rlist'

# just a simple test to ensure that rbasiclistbox is running inside a container.
App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Basic List Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F10 to escape from here"

  #list = %W{ bhikshu boddisattva avalokiteswara mu mun kwan paramita prajna samadhi sutra shakyamuni }
  alist = File.open("data/brew.txt",'r').readlines
  list2 = File.open("data/gemlist.txt",'r').readlines
  lb = nil
  #vimsplit :row => 1, :col => 0, :suppress_borders => false, :width => 60, :height => Ncurses.LINES-2, :weight => 0.4, :orientation => :VERTICAL do |s|
  flow :margin_top => 1, :item_width => 50 , :height => FFI::NCurses.LINES-2 do
    lb = listbox :list => alist, :suppress_borders => false, :title => "[ brew packages ]",
      :left_margin => 1
    lb.show_selector = false
    
    lb2 = listbox :list => list2, :justify => :left, :title => "[ gems ]", :suppress_borders => false,
      :left_margin => 1
    end
    #label({:text => "checking overwrite from list", :row => 10, :col => 60})
    #label({:text => "checking overwrite from list 1", :row => 11, :col => 60})
  label({:text => "Press F4 and F5 to test popup, space or enter to select", :row => Ncurses.LINES-1, :col => 0})

  @form.bind_key(FFI::NCurses::KEY_F4) { row = lb.current_index+lb.row; col=lb.col+lb.current_value.length+1;  ret = popuplist(%w[ andy berlioz strauss tchaiko matz beethoven], :row => row, :col => col, :title => "Names", :bgcolor => :blue, :color => :white) ; alert "got #{ret} "}
  @form.bind_key(FFI::NCurses::KEY_F5) {  list = %x[ls].split("\n");ret = popuplist(list, :title => "Files"); alert "Got #{ret} #{list[ret]} " }
end # app
