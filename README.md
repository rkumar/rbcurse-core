# rbcurse-core

** Works on 1.9.3 **

Contains core widgets and infrastructure of rbcurse ncurses toolkit. rbcurse helps to easily build
ncurses application for text terminals.

rbcurse-core contains basic widgets for constructing applications.  These include:

* field

* buttons - checkbox, radio, toggle

* list

* textview

* dialogs and popup

* table

* menu

* tabbedpane

* tree

* application header

* status line

Core intends to be : 

   * stable, 

   * have very few changes, 

   * be backward compatible.

   * simple, maintainable code

## Testing Status

   * Works on 1.9.3-p392  (my environment is zsh 5.0.x, tmux, TERM=screen-256color, OSX ML)  
   * Cannot promise if working on 1.8.7, am making some fixes (thanks hramrach), but may not be able to to
     support 1.8.7 indefinitely. Please submit bugs on 1.8.7 if you find them.

## Other 

I shall be standardizing core over the next one or two minor versions. I shall also be simplifying code as much as possible to make it maintainable and more bug-free.

Method names in some classes may change, and one or two widget names will change. rbasiclistbox will become listbox while the old listbox that has moved to extras will become something like editlistbox. Similarly the old table will become edittable in extras, whereas tabularwidget will becoming table in core.
The new tabbedpane and messagebox will replace the old ones, while the old ones will move to /deprecated.

Color formatting needs to be standardized and a proper API firmed up for that, so user code does not get affected by internal changes. Similarly, work on textpad may get integrated into some widgets since it could simplify their code.

I have not yet begun working on extras and experimental as yet. This contains code that was working
in rbcurse-1.5, but not tested or touched since then. I will only get around there after polishing
the core a bit more. The code lies on github.

## Install

   `gem install rbcurse-core`        # just the core

   To install more:

   `gem install rbcurse-extras`        # the core, and extra stuff

   `gem install rbcurse`             # the core, extra and experimental stuff

## Examples

   Some examples have dependencies.

   * dbdemo requires sqlite3 gem (and sqlite).
   * testlistbox require ri documentation 
      `rvm docs generate-ri`
     I have improved this demo and released it as the gem 'ribhu' (ri browser).

## See also

* rbcurse-extras - <http://github.com/rkumar/rbcurse-extras/>

* rbcurse-experimental - <http://github.com/rkumar/rbcurse-experimental/>

* rbcurse - <http://github.com/rkumar/rbcurse/>

## License

  Same as ruby license.

  (c) copyright rkumar, 2008-2013.
