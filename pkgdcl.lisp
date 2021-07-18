#+xcvb (module ())

(cl:defpackage :command-line-arguments
  (:use :cl :uiop)
  (:export
   #:*command-line-arguments*
   #:*command-line-options*
   #:*command-line-option-specification*
   #:process-command-line-options
   #:compute-and-process-command-line-options
   #:get-command-line-arguments
   #:handle-command-line
   #:show-option-help
   #:define-command
   #:command-line-arity
   ))
