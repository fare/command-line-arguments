#+xcvb (module ())

(cl:defpackage :command-line-arguments
  (:use :cl :asdf/driver)
  (:export
   #:*command-line-arguments*
   #:*command-line-options*
   #:*command-line-option-specification*
   #:process-command-line-options
   #:compute-and-process-command-line-options
   #:get-command-line-arguments
   #:handle-command-line
   #:show-option-help
   ))
