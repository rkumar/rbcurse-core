require 'rbcurse/core/util/app'


App.new do 
def help_text
    <<-eos
         Help for tabular widgets   

    <space>     -  select a row
    <Ctr-space> - range select
    <u>         - unselect all
    <a>         - select all
    <*>         - invert selection
    <ENTER>     - sort given field (press on header)

         Motion keys 
    Usual for lists and textview such as 
    j, k, h, l
    w and b for field
    C-d and C-b
    gg and G

    eos
end
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Tabular Demo", :text_right =>"Fat-free !", 
      :color => :black, :bgcolor => :green #, :attr => :bold 
  message "Press F10 to exit from here, F1 for help, F2 for menu"

  h = %w[ Id Title Prio Status]
  file = "data/table.txt"
  lines = File.open(file,'r').readlines 
  arr = []
  lines.each { |l| arr << l.split("|") }
  flow :margin_top => 1, :height => FFI::NCurses.LINES-3 do
    tw = tabular_widget :print_footer => true #:height => 20 #:expand
    tw.columns = h
    tw.column_align 0, :right
    tw.set_content arr
  end # stack
  status_line :row => FFI::NCurses.LINES-1
end # app
