#+xcvb (module (:depends-on ("asdf-encodings" (:asdf "hu.dwim.stefil"))))

(defpackage :command-line-arguments/test
  (:use :cl :command-line-arguments :alexandria :hu.dwim.stefil))

(in-package :command-line-arguments/test)

;;; Testing the asdf-encodings library.

(defsuite* (test-suite
            :in root-suite
            :documentation "Testing command-line-arguments"))

(defparameter *opt-spec*
 '((("all" #\a) :type boolean :documentation "do it all")
   ("blah" :type string :initial-value "blob" :documentation "This is a very long multi line documentation. The function SHOW-OPTION-HELP should display this properly indented, that is all lines should start at the same column.")
   (("verbose" #\v) :type boolean :documentation "include debugging output")
   (("file" #\f) :type string :documentation "read from file instead of standard input")
   (("xml-port" #\x) :type integer :optional t :documentation "specify port for an XML listener")
   (("http-port" #\h) :type integer :initial-value 80 :documentation "specify port for an HTTP listener")
   ("enable-cache" :type boolean :documentation "enable cache for queries")
   ("path" :type string :list t :optional t :documentation "add given directory to the path")
   ("port" :type integer :list (:initial-contents (1 2)) :optional t :documentation "add a normal listen on given port")))

(deftest test-process-command-line-options ()
  (multiple-value-bind (options arguments)
    (process-command-line-options
     *opt-spec*
     '("--all" "--no-verbose" "--file" "foo" "-f" "-v" "-v"
       "-x" "--disable-cache" "-h" "8080"
       "--no-port" "--port" "3" "--port=4"
       "--path" "/foo" "--path" "/bar"
       "--" "--foo" "bar" "baz"))
    (is (equal arguments '("--foo" "bar" "baz")))
    (is (equal (sort (alexandria:plist-alist options) 'string< :key 'car)
               '((:all . t) (:blah . "blob") (:enable-cache) (:file . "-v") (:file . "foo")
                 (:http-port . 8080) (:http-port . 80) (:path "/foo" "/bar") (:port 3 4)
                 (:verbose . t) (:verbose) (:xml-port . t)))))
  nil)

(deftest test-show-option-help ()
  (is (with-output-to-string (s) (show-option-help *opt-spec* :stream s))
      "  --all -a                        boolean  do it all
  --blah                          string   This is a very long multi line documentation. The
                                           function SHOW-OPTION-HELP should display this properly
                                           indented, that is all lines should start at the same
                                           column. (default: \"blob\")
  --verbose -v                    boolean  include debugging output
  --file -f                       string   read from file instead of standard input
  --xml-port -x                   integer  specify port for an XML listener
  --http-port -h                  integer  specify port for an HTTP listener (default: 80)
  --enable-cache                  boolean  enable cache for queries
  --path                          string   add given directory to the path
  --port                          integer  add a normal listen on given port

")
  nil)

