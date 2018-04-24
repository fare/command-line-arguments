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

The `define-command` macro may be used to simultaneously define the
following three functions which are useful for defining a function
which may be invoked from the command line.  For example, the
following invocation of `define-command` on `FOO` results in:

    (define-command foo (noun verb &spec +command-line-spec+ &aux scratch)
      "Usage: foo NOUN VERB [OPTIONS...]
    Do VERB to NOUN according to OPTIONS."
      #.(format nil "~%Built with ~a version ~a.~%"
                (lisp-implementation-type)
                (lisp-implementation-version))
      (declare (verbose))
      (when help (show-help-for-foo))
      #|...implementation...|#)

show-help-for-FOO
:   Prints help and option information for FOO to STDOUT and then
    exits with `uiop:quit`.

    The docstring passed to `define-command` becomes the help text
    printed before options.  A second docstring passed as the fourth
    argument to `define-command` is printed after the options.

run-FOO
:   Similar to the `main` example above this function is meant to be
    used as a `defsystem` `:entry-point`.  It runs FOO on the command
    line arguments by invoking `handle-command-line`.

FOO
:   The `&body` passed to `define-command` becomes the body of the FOO
    function.  The positional required command line arguments become
    named arguments to FOO and the command line options passed in
    behind the `&spec` keyword in the argument list become keyword
    arguments to FOO.  When supplied `:initial-value` properties of
    command lines become defaults of the corresponding keyword
    arguments.  When supplied `:action` properties of command line
    arguments have calls to their actions prepended to the body of the
    function.  Actions are only called when the keyword argument has a
    non-nil value.

    The macro-expanded prototype for FOO in this example would be the
    following.
    
        (DEFUN FOO (NOUN VERB &KEY B CHECK VERBOSE WARN HELP VERSION &AUX SCRATCH))

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
