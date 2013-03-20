require 'rbcurse/core/util/app'
require 'sqlite3'
#require 'rbcurse/experimental/resultsettextview.rb'
#require 'rbcurse/experimental/widgets/undomanager'

# @return array of table names from selected db file
def get_table_names
  raise "No database file selected." unless $current_db

  $tables = get_data "select name from sqlite_master"
  $tables.collect!{|x| x[0] }  ## 1.9 hack, but will it run on 1.8 ??
  $tables
end
def get_column_names tbname
  get_metadata tbname
end
def connect dbname
  $log.debug "XXX:  CONNECT got #{dbname} "
  $current_db = dbname
  $db = SQLite3::Database.new(dbname) if dbname

  return $db
end
def get_data sql
  $log.debug "SQL: #{sql} "
  $columns, *rows = $db.execute2(sql)
  $log.debug "XXX COLUMNS #{sql}  "
  content = rows
  return nil if content.nil? or content[0].nil?
  $datatypes = content[0].types #if @datatypes.nil?
  return content
end
def get_metadata table
  get_data "select * from #{table} limit 1"
  #$columns.collect!{|x| x[0] }  ## 1.9 hack, but will it run on 1.8 ??
  return $columns
end
#
# creates a popup for selection given the data, and executes given block with
#  following return value.
# @return [String] if mode is :single
# @return [Array] if mode is :multiple
#
def create_popup array, selection_mode=:single,  &blk
  #raise "no block given " unless block_given?
  listconfig = {'bgcolor' => 'blue', 'color' => 'white'}
  listconfig[:selection_mode] = selection_mode
  ix = popuplist array, listconfig
  if ix
    if selection_mode == :single
      value = array[ix]
      blk.call value
    else
      #values = array.select {|v| ix.include? v}
      values = []
      array.each_with_index { |v, i| values << v if ix.include? i }
      blk.call(values)
    end
  end
end

def view_data name, fields='*'
  stmt = "select #{fields} from #{name}"
  stmt << $where_string if $where_string
  stmt << $order_string if $order_string
  view_sql stmt
  @form.by_name['tarea'] << stmt if @form # nil when called from menu
end
def view_sql stmt
  begin
  content = get_data stmt
  if content.nil?
  else
    require 'rbcurse/core/widgets/tabular'
    t = Tabular.new do |t|
      t.headings = $columns
      t.data=content   
    end
    view t.render
  end
  rescue => err
    $log.error err.to_s
    $log.error(err.backtrace.join("\n"))
    textdialog [err.to_s, *err.backtrace], :title => "Exception"
  end
end

App.new do 
  #header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Database Demo", :text_right =>"enabled"
  form = @form
  mylabel = "a field"
  $catch_alt_digits = true # use M-1..9 in textarea
  $current_table = nil
  $current_db = nil # "testd.db"
  connect $current_db if $current_db
  def which_field
    alert "curent field is #{form.get_current_field} "
  end

  def get_commands
    %w{ which_field }
  end
  def help_text
    <<-eos
               DBDEMO HELP 

      This is some help text for dbdemo.
      We are testing out this feature.

      Alt-d    -   Select a database
      <Enter>      on a table, view data (q to close window)
      <Space>      on a table, display columns in lower list

                COLUMN LIST KEYS
      <Space>      on a column for multiple select
      <Ctrl-Space> on a column for range select/deselect from previous selection
      <Enter>      on column table to view data for selected columns
             u     unselect all
             a     select all
             *     invert selection
      F4           View data for selected table (or columns if selected)

      q or C-q     Close the data window that comes on Enter or F4

      Alt-x    -   Command mode (<tab> to see commands and select)
      :        -   Command mode
      Alt-z    -   Commands in TextArea
      
                Sql Entry Area
      C-x e        Edit in $EDITOR or vi
      M-?          To see other key-bindings
      F4           Execute SQL (there should be only one sql).


                Result Set  (this is not present in this demo any longer - moved
                to rbcurse-extras)
      ,            Prev row (mnemonic <)
      .            Next row (mnemonic >)
      <            First row
      >            Last row

      F10      -   Quit application



      -----------------------------------------------------------------------
      Hope you enjoyed this help.
    eos
  end
  def ask_databases
      names = Dir.glob("*.{sqlite,db}")
      if names
        ix = popuplist( names )
        if ix
          value = names[ix]
          connect(value);
          @form.by_name["tlist"].list(get_table_names)
        end
        
      else
        alert "Can't find a .db or .sqlite file"
      end
  end
  @form.help_manager.help_text = help_text()
  # TODO accelerators and 
  # getting a handle for later use
  mb = menubar do
    keep_visible true
    #@toggle_key=KEY_F2
    menu "File" do
      item "Open", "O" do
        accelerator "Ctrl-O"
        command do 
          alert "HA!! you wanted to open a file?"
        end
      end
      menu "Database" do
        item_list do
          Dir.glob("**/*.{sqlite,db}")
        end
        command do |menuitem, text|
          connect text
          form.by_name["tlist"].list(get_table_names)
        end
      end
      menu "Tables" do
        item_list do
          if $current_db
            get_table_names
          end
        end
        command do |menuitem, text|
          $current_table = text
          #alert(get_column_names(text).join(", "))
          create_popup(get_column_names(text), :multiple) { |value| view_data( text, value.join(",")) }
        end
      end
      item "New", "N" 
      separator
      item "Exit", "x"  do 
        command do
          throw(:close)
        end
      end
      item "Cancel Menu" do
        accelerator "Ctrl-g"
      end

    end # menu
    menu "Window" do
      item "Tile", "T"
      menu "Find" do
        item "More", "M"
        $x = item "Less", "L" do
          #accelerator "Ctrl-X"
          command do
            alert "You clickses on Less"
          end
        end
        menu "Size" do
          item "Zoom", "Z"
          item "Maximize", "X"
          item "Minimize", "N"
        end
      end
    end
    menu "Others" do
      require 'rbcurse/core/include/appmethods.rb'
      item "Shell Output" do
        command { shell_output }
      end
      item "Suspend" do
        command { suspend }
      end
    end
  end # menubar
  mb.toggle_key = FFI::NCurses::KEY_F2
  mb.color = :white
  mb.bgcolor = :blue
  @form.set_menu_bar mb
  tv = nil
  flow :margin_top => 1 do
    col1w = 20
    stack :width_pc => 20 do
      text = "No tables"
      if !$current_db
        text = "Select DB first. Press Alt-D"
      end
      tlist = basiclist :name => "tlist", :list => [text], :title => "Tables", :height => 10,
        :selected_color => 'cyan', :selected_bgcolor => 'black' , :selected_attr => Ncurses::A_REVERSE,
        :help_text => "Enter to View complete table, Space to select table and view columns",
        :should_show_focus => true,
        :selection_mode => :single
      tlist.bind(:PRESS) do |eve|
        if $current_db
          # get data of table
          view_data eve.text
          #tv.sqlite $current_db, eve.text, "select * from #{eve.text} " # TODO in core
        else
          ask_databases
        end
      end
      #tlist.bind(:ENTER_ROW) do |eve|
        # too much confusion between selected and focussed row
        #$current_table = eve.text if $db
      #end
      clist = basiclist :name => "clist", :list => ["No columns"], :title => "Columns", :height => 14, 
        :selection_mode => :multiple,
        :selected_color => 'cyan', :selected_bgcolor => 'black' , :selected_attr => Ncurses::A_REVERSE,
        :help_text => "Enter to View selected fields, Space to select columns, w - where, o-order"
      tlist.bind(:LIST_SELECTION_EVENT) do |eve|
        $selected_table = eve.source[eve.firstrow]
        $current_table = $selected_table
        clist.data = get_column_names $selected_table
      end
      clist.bind(:PRESS) do |eve|
        # get data of table
        if $selected_table
          cols = "*"
          c = clist.get_selected_values
          unless c.empty?
            cols = c.join(",")
          end
          view_data $selected_table, cols
        else
          alert "Select a table first." 
        end
      end
      clist.bind_key('w', 'add to where condition') {
        c = clist.current_value
        $where_columns ||= []
        hist = ["#{c} = "]
        w = rb_gets("where "){ |q| q.default = "#{c} = "; q.history = hist }
        $where_columns << w if w
        message "where: #{$where_columns.last}. Press F4 when done"
        $log.debug "XXX: WHERE: #{$where_columns} "
      }
      clist.bind_key('o', 'add to order by') {
        c = clist.current_value
        $order_columns ||= []
        $order_columns << c if c
        message "order (asc): #{$order_columns.last}. Press F4 when done"
        $log.debug "XXX: ORDER: #{$order_columns} "
      }
      clist.bind_key('O', 'add to ordery by desc') {
        c = clist.current_value
        $order_columns ||= []
        $order_columns << " #{c} desc " if c
        message "order: #{$order_columns.last}"
        $log.debug "XXX: ORDER: #{$order_columns}. Press F4 when done"
      }
      @statusline = status_line
      #wg = get_color($datacolor, 'white','green')
      #wb = get_color($datacolor, 'white','blue')
      @statusline.command { 
        # trying this out. If you want a persistent message that remains till the next on
        #  then send it in as $status_message
        text = $status_message.value || ""
        if !$current_db
          #"[%-s] %s" % [ "Select a Database", text]
          "[%-s] %s" % [ "#[bg=red,fg=yellow]Select a Database#[end]", text]
          #[ [nil, "%-22s" % Time.now, nil], [$errorcolor, " [Select a Database ]", FFI::NCurses::A_BOLD], [nil, text, nil] ]
        elsif !$current_table
          "[DB: #[fg=white,bg=blue]%-s#[end] | %-s ] %s" % [ $current_db || "None", $current_table || "#[bg=red,fg=yellow]Select a table#[end]", text] 
          #[ [nil, "%-22s [DB: %-s | " % [Time.now, $current_db || "None" ],nil], [$errorcolor, " Select a Table ]", FFI::NCurses::A_BOLD], [nil, text, nil] ]
        else
          "DB: #[fg=white,bg=green,bold]%-s#[end] | #[bold]%-s#[end] ] %s" % [ $current_db || "None", $current_table || "----", text] 
          #[ [nil, "%-22s [DB: " % Time.now, nil], [wb, " #{$current_db} ", FFI::NCurses::A_BOLD],
          #[wg, $current_table || "----", FFI::NCurses::A_BOLD], [nil, text, nil] ]
        end
      }
      @adock = nil
      keyarray = [
        ["F1" , "Help"], ["F10" , "Exit"], 
        ["F2", "Menu"], ["F4", "View"],
        ["M-d", "Datebase"], ["M-t", "Table"],
        ["M-x", "Command"], nil
      ]
      tlist_keyarray = keyarray + [ ["Sp", "Select"], nil, ["Enter","View"] ]

      clist_keyarray = keyarray + [ ["Sp", "Select"], ["C-sp", "Range Sel"], 
        ["Enter","View"], ['w', 'where'],
        ["o","order by"], ['O', 'order desc']
      ]
      tarea_keyarray = keyarray + [ ["M-z", "Commands"], nil ]
      #tarea_sub_keyarray = [ ["r", "Run"], ["c", "clear"], ["w","Save"], ["a", "Append next"], 
      #["y", "Yank"], ["Y", "yank pop"] ]
      tarea_sub_keyarray = [ ["r", "Run"], ["c", "clear"], ["e", "Edit externally"], ["w","Kill Ring Save (M-w)"], ["a", "Append Next"], 
        ["y", "Yank (C-y)"], ["Y", "yank pop (M-y)"],
        ["u", "Undo (C-_)"], ["R", "Redo (C-r)"],
      ]

      gw = get_color($reversecolor, 'green', 'black')
      @adock = dock keyarray, { :row => Ncurses.LINES-2, :footer_color_pair => $datacolor, 
        :footer_mnemonic_color_pair => gw }
      @adock.set_key_labels tlist_keyarray, :tables
      @adock.set_key_labels clist_keyarray, :columns
      @adock.set_key_labels tarea_sub_keyarray, :tarea_sub
      @adock.set_key_labels tarea_keyarray, :tarea
      tlist.bind(:ENTER) { @adock.mode :tables }
      clist.bind(:ENTER) { @adock.mode :columns }

      reduce = lambda { |obj|
        obj.height -= 1 if obj.height > 3
      }
      increase = lambda { |obj|
        obj.height += 1 if obj.height + obj.row < Ncurses.LINES-2
      }
      _lower = lambda { |obj|
        obj.row += 1 if obj.height + obj.row < Ncurses.LINES-2
      }
      _raise = lambda { |obj|
        obj.row -= 1 if obj.row > 2
      }
      [clist, tlist].each do |o|
        o.bind_key([?\C-x, ?-]){ |o| reduce.call(o) }
        o.bind_key([?\C-x, ?+]){ |o| increase.call(o) }
        o.bind_key([?\C-x, ?v]){ |o| _lower.call(o) }
        o.bind_key([?\C-x, ?6]){ |o| _raise.call(o) }
      end


      @form.bind_key([?q,?q], 'quit') { throw :close }
      @form.bind_key(?\M-t, 'select table') do
        if $current_db.nil?
          alert "Please select database first"
        else
          create_popup( get_table_names,:single) {|value| $selected_table = $current_table =  value}
        end
      end
      @form.bind_key(?\M-d, 'select database') do
        ask_databases
      end
      @form.bind_key(FFI::NCurses::KEY_F4, 'view data') do
        $where_string = nil
        $order_string = nil
        if $where_columns
          $where_string = " where " + $where_columns.join(" and ")
        end
        if $order_columns
          $order_string = " order by " + $order_columns.join(" , ")
        end
        # mismatch between current and selected table
        if $current_table
          cols = "*"
          c = clist.get_selected_values
          unless c.empty?
            cols = c.join(",")
          end
          view_data $current_table, cols
        else
          alert "Select a table first." 
        end
      end
    end # stack
    stack :width_pc => 80 do
      tarea = textarea :name => 'tarea', :height => 5, :title => 'Sql Statement'
      #undom = SimpleUndo.new tarea
      tarea.bind_key(Ncurses::KEY_F4, 'view data') do
        text = tarea.get_text
        if text == ""
          alert "Please enter a query and then hit F4. Or press F4 over column list"
        else
          view_sql tarea.get_text
        end
      end
      tarea.bind(:ENTER) { @adock.mode :tarea }
      tarea.bind_key(?\M-z, 'textarea submenu'){

        hash = { 'c' => lambda{ tarea.remove_all },
          'e' => lambda{ tarea.edit_external },
          'w' => lambda{ tarea.kill_ring_save },
          'a' => lambda{ tarea.append_next_kill },
          'y' => lambda{ tarea.yank },
          'Y' => lambda{ tarea.yank_pop },
          'r' => lambda{ view_sql tarea.get_text },
          'u' => lambda{ tarea.undo },
          'R' => lambda{ tarea.redo },
      }


      @adock.mode :tarea_sub
      @adock.repaint
      keys = @adock.get_current_keys
      while((ch = @window.getchar()) != ?\C-c.getbyte(0) )
        if ch < 33 || ch > 126
          Ncurses.beep
        elsif !keys.include?(ch.chr) 
          Ncurses.beep
        else
          hash.fetch(ch.chr).call
          #opt_file ch.chr
          break
        end
      end
      @adock.mode :normal
      } # M-z
      flow do
        #button_row = 17
        button "Save" do
          @cmd_history ||= []
          filename = rb_gets("File to append contents to: ") { |q| q.default = @oldfilename; q.history = @cmd_history }

          if filename
            str = tarea.get_text
            File.open(filename, 'a') {|f| f.write(str) } 
            @oldfilename = filename
            @cmd_history << filename unless @cmd_history.include? filename

            message "Appended data to #{filename}"
          else
            message "Aborted operation"
          end
          #hide_bottomline
        end
        button "Read" do
          filter = "*"
          #str = choose filter, :title => "Files", :prompt => "Choose a file: "
          cproc = Proc.new { |str| Dir.glob(str + "*") }
          str = rb_gets "Choose a file: ", :title => "Files", :tab_completion => cproc, 
            :help_text => "Press <tab> to complete filenames. C-a, C-e, C-k. Alt-?"
          if str && File.exists?(str)
            begin
              tarea.set_content(str) 
              message "Read content from #{str} "
            rescue => err
              print_error_message "No file named: #{str}: #{err.to_s} "
            end
          end
        end
        #ok_button = button( [button_row,30], "OK", {:mnemonic => 'O'}) do 
        #end
      end
      blank
      #tv = RubyCurses::ResultsetTextView.new @form, :row => 1,  :col => 1, :width => 50, :height => 16
      #tv = resultsettextview :name => 'resultset', :height => 18 , :title => 'DB Browser', :print_footer => true

    end
  end
end # app
