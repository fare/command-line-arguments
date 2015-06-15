command-line-arguments
======================

A library for parsing command-line arguments.

Use it in conjunction with [asdf:program-op](https://common-lisp.net/project/asdf/) or
[cl-launch](http://cliki.net/cl-launch) for portable processing of command-line arguments.


Usage
-----

This library is woefully under-documented.
See the examples below, and read [the source code](parse.lisp) for details.
Here is what a prototypical use looks like:

    (defparameter +command-line-spec+
      '(((#\b) :type boolean :optional t :documentation "what optional -b flag does")
        (("check" #\c) :type string :optional t :documentation "a --check or -c flag that takes a string")
        (("verbose") :type boolean :optional t :documentation "only a verbose --verbose is accepted")
        (("warn" "warning" #\w) :type boolean :optional t :documentation "multiple spellings possible")
        (("help" #\h #\?) :type boolean :optional t :documentation "--help -h -?, good practice to have")
        (("version" #\V) :type boolean :optional t :documentation "--version or -V, you get the idea")))

    ;; for the positional arguments, see below :positional-arity and :rest-arity
    (defun my-program-function (arg1 arg2 rest-args &key b check verbose warn help version)
       (when help (show-option-help +command-line-spec+ :sort-names t) (uiop:quit))
       (when version (show-version) (uiop:quit))
       ...)

    (defun main (args)
      (handle-command-line
        ;; the spec as above, or prepared with prepare-command-line-options-specification
        +command-line-spec+
        ;; the function to call with the arguments as parsed
        'my-program-function
        ;; the arguments to parse
        :command-line args
        ;; the program name to use in case of an error message
        :name "my-program"
        ;; the number of mandatory positional arguments for this command (default: 0)
        :positional-arity 2
        ;; What to do with the rest of the positional arguments.
        ;; T means pass the list of the rest of the command-line-arguments as one lisp argument.
        ;; NIL means ignore it. A keyword means pass this rest as a keyword argument.
        :rest-arity t))


Examples
--------

For very simple examples of actual uses, see
my [tthsum](https://gitlab.common-lisp.net/frideau/tthsum/blob/master/main.lisp) clone in Lisp or
my [workout-timer](http://gitlab.common-lisp.net/frideau/workout-timer/blob/master/timer.lisp).

For a much more elaborate use, see [xcvb](http://gitlab.common-lisp.net/xcvb/xcvb)
— unhappily, XCVB has gone mostly unmaintained since 2012,
so the example might not be usefully runnable.


Homepage
--------

  <http://common-lisp.net/project/qitab/>


See also
--------

For a fancier take on the same general idea, see Didier Verna's CLON:

  <http://www.lrde.epita.fr/~didier/software/lisp/clon.php>

CLON has much more features than this library, but is much more complex and slighly less portable.
