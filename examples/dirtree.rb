require 'rbcurse/core/util/app'
require 'fileutils'
require 'rbcurse/core/widgets/tree/treemodel'
#require 'rbcurse/common/file'
require './common/file'

def _directories wd
  $log.debug " directories got XXX: #{wd} "
  d = Dir.new(wd)
  ent = d.entries.reject{|e| !File.directory? File.join(wd,e)}
  $log.debug " directories got XXX: #{ent} "
  ent.delete(".");ent.delete("..")
  return ent
end
App.new do 
  def help_text
    ["Press <Enter> to expand/collapse directories. Press <space> to list a directory",
      "Press <space> on filename to page it, or <ENTER> to view it in vi",
      "At present the PWD may not be updated, so you'll just have to be in the correct",
      "dir to actually view the file"]
  end
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Yet Another Dir Lister", :text_right =>"Directory Lister" , :color => :white, :bgcolor => :black #, :attr =>  Ncurses::A_BLINK
  message "Press Enter to expand/collapse, <space> to view in lister. <F1> Help"

  pwd = Dir.getwd
  entries = _directories pwd
  patharray = pwd.split("/")
  # we have an array of path, to add recursively, one below the other
  nodes = []
  nodes <<  TreeNode.new(patharray.shift)
  patharray.each do |e| 
    nodes <<  nodes.last.add(e)
  end
  last = nodes.last
  nodes.last.add entries
  model = DefaultTreeModel.new nodes.first
     


  ht = FFI::NCurses.LINES - 2
  borderattrib = :normal
  flow :margin_top => 1, :margin_left => 0, :width => :expand, :height => ht do
    @t = tree :data => model, :width_pc => 30, :border_attrib => borderattrib
    @t.bind :TREE_WILL_EXPAND_EVENT do |node|
      path = File.join(*node.user_object_path)
      dirs = _directories path
      ch = node.children
      ch.each do |e| 
        o = e.user_object
        if dirs.include? o
          dirs.delete o
        else
          # delete this child since its no longer present TODO
        end
      end
      #message " #{node} will expand: #{path}, #{dirs} "
      node.add dirs
    end
    @t.bind :TREE_SELECTION_EVENT do |ev|
      if ev.state == :SELECTED
        node = ev.node
        path = File.join(*node.user_object_path)
        if File.exists? path
          files = Dir.new(path).entries
          files.delete(".")
          @l.list files 
          #TODO show all details in filelist
          @current_path = path
        end
      end
    end # select
    @t.expand_node last # 
    @t.mark_parents_expanded last # make parents visible
    @l = listbox :width_pc => 70, :border_attrib => borderattrib

    @l.bind :LIST_SELECTION_EVENT  do |ev|
      message ev.source.text #selected_value
      _f = File.join(@current_path, ev.source.text)
      file_page   _f if ev.type == :INSERT
      #TODO when selects drill down
      #TODO when selecting, sync tree with this
    end
    # on pressing enter, we edit the file using vi or EDITOR
    @l.bind :PRESS  do |ev|
      _f = File.join(@current_path, ev.source.text)
      file_edit _f if File.exists? _f
    end
  end
  status_line :row => FFI::NCurses.LINES - 1
end # app
