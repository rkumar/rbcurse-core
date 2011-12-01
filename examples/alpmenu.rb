require 'rbcurse/core/util/app'

  App.new do 
    #title "Demo of Menu - rbcurse"
    #subtitle "Hit F1 to quit, F2 for menubar toggle"
    header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Alpine Menu Demo", :text_right =>""

    stack :margin_top => 10, :margin_left => 15 do
      #w = "Messages".length + 1
      w = 60
      menulink :text => "&View Todo", :width => w, :description => "View TODO in sqlite"  do |s|
        message "Pressed #{s.text} "
        load './dirtree.rb'
        #require './viewtodo'; todo = ViewTodo::TodoApp.new; todo.run
      end
      blank
      menulink :text => "&Edit Todo", :width => w, :description => "Edit TODO in CSV"  do |s|
        message "Pressed #{s.text} "
        load './tabular.rb'
        #require './testtodo'; todo = TestTodo::TodoApp.new; todo.run
      end
      blank
      menulink :text => "&Messages", :width => w, :description => "View messages in current folder"  do |s|
        message "Pressed #{s.text} "
        load './tasks.rb'
      end
      blank
      menulink :text => "&Compose", :width => w, :description => "Compose a mail"  do |s|
        message "Pressed #{s.getvalue} "
        load './dbdemo.rb'
      end
      blank
      # somehow ? in mnemonic won't work
      menulink :text => "&Setup", :width => w, :description => "Configure Alpine options"  do |s|
        #message "Pressed #{s.text} "
        alert "Not done!"
      end
      blank
      menulink :text => "&Quit", :width => w, :description => "Quit this application"  do |s|
        quit
      end
      @form.bind(:ENTER) do |w|
        header.text_right = w.text
      end
    end # stack
  end # app
