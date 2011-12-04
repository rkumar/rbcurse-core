require 'rbcurse/core/util/app'

App.new do 
  def app_menu
      menu = PromptMenu.new self do
        item :e, :edit
        item :o, :open_new
        item :d, :delete
        item :u, :undo_delete
        #item :y, :yank
        #item :p, :paste
        item :/, :search
      end
      menu.display_new :title => "Menu"
  end
  # to execute when app_menu is invoked
  def execute_this *cmd
    cmd = cmd[0][0] # extract first letter of command
    cmdi = cmd.getbyte(0)
    case cmd
    when 'e','o','p'
      @window.ungetch cmdi
    when 'y','d'
      @window.ungetch cmdi
      @window.ungetch cmdi
    when 'u'
      @window.ungetch cmd.upcase.getbyte(0)
    when 's'
      @window.ungetch ?\/.getbyte(0)
    end
  end
def help_text
    <<-eos
         Help for tabular widgets   
         ------------------------

         Keys that can be used on header

    <ENTER>     - sort given field (press on header)
    <->         - press <minus> to reduce column width
    <+>         - press <plus> to increase column width

         Keys that can be used on data rows

    <space>     -  select a row
    <Ctr-space> - range select
    <u>         - unselect all (conflicts with vim keys!!)
    <a>         - select all
    <*>         - invert selection

    </>         - <slash> for searching, 
                  <n> to continue searching

    Keys specific to this example

    <e>         - edit current row
    <dd>        - delete current row or <num> rows
    <o>         - insert a row after current one
    <U>         - undo delete

         Motion keys 

    Usual for lists and textview such as :
    j, k, h, l
    w and b for (next/prev) column
    C-d and C-b
    gg and G

    eos
end
def edit_row tw
  row = tw.current_value
  h   = tw.columns
  _edit h, row, " Edit "
  tw.repaint_required true
end
def insert_row tw
  h   = tw.columns
  row = []
  h.each { |e| row << "" }
  ret = _edit h, row, "Insert"
  if ret
    tw.insert tw.real_index(), row
    tw.repaint_required true
  end
end

# making a generic edit messagebox - quick dirty
def _edit h, row, title
  _l = longest_in_list h
  _w = _l.size
  config = { :width => 70, :title => title }
  bw = get_color $datacolor, :black, :white
  mb = MessageBox.new config do
    h.each_with_index { |f, i| 
      add Field.new :label => "%*s:" % [_w, f], :text => row[i].chomp, :name => i.to_s, 
        :bgcolor => :cyan,
        :display_length => 50,
        :label_color_pair => bw
    }
    button_type :ok_cancel
  end
  index = mb.run
  return nil if index != 0
  h.each_with_index { |e, i| 
    f = mb.widget(i.to_s)
    row[i] = f.text
  }
  row
end
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Tabular Demo", :text_right =>"Fat-free !", 
      :color => :black, :bgcolor => :green #, :attr => :bold 
  message "Press F10 to exit, F1 for help, : for menu"

  h = %w[ Id Title Priority Status]
  file = "data/table.txt"
  lines = File.open(file,'r').readlines 
  arr = []
  lines.each { |l| arr << l.split("|") }
  flow :margin_top => 1, :height => FFI::NCurses.LINES-3 do
    tw = tabular_widget :print_footer => true
    tw.columns = h
    tw.column_align 0, :right
    tw.set_content arr
    tw.bind_key([?d,?d]) { tw.delete_line }
    tw.bind_key(?U) { tw.undo_delete }
    tw.bind_key(?e) {  edit_row tw }
    tw.bind_key(?o) {  insert_row tw }
  end # stack
  status_line :row => FFI::NCurses.LINES-1
  @form.bind_key(?:) {  app_menu }
end # app
