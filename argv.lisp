;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                  ;;;
;;; Free Software available under an MIT-style license. See LICENSE  ;;;
;;;                                                                  ;;;
;;; Copyright (c) 2009 ITA Software, Inc.  All rights reserved.      ;;;
;;;                                                                  ;;;
;;; Original author: Francois-Rene Rideau                            ;;;
;;;                                                                  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#+xcvb (module (:depends-on ("pkgdcl")))

(in-package :command-line-arguments)

(declaim (ftype (function (t t) (values t t)) process-command-line-options))

(defun get-command-line-arguments ()
  uiop:*command-line-arguments*)

(defun compute-and-process-command-line-options (specification)
  (process-command-line-options specification (get-command-line-arguments)))

(define-condition command-line-arity (error)
  ((name :initarg :name :reader name)
   (arguments :initarg :arguments :reader arguments)
   (rest-arity :initarg :rest-arity :reader rest-arity)
   (positional-arity :initarg :positional-arity :reader positional-arity))
  (:report
   (lambda (condition stream)
     (with-slots (name arguments rest-arity positional-arity) condition
       (if (< (length arguments) positional-arity)
           (format stream "~@[~A: ~] Too few arguments. Expected~@[ at least~] ~A, got ~A ~S"
                   name rest-arity positional-arity (length arguments) arguments)
           (format stream "~@[~A: ~] Too many arguments. Expected only ~A, got ~A ~S"
                   name positional-arity (length arguments) arguments)))))
  (:documentation
   "Indicates the wrong number of arguments were given on the command line."))

(defun invoke-command-line-handler (function options arguments &key
                                    (positional-arity 0) (rest-arity nil) name)
  (let ((l (length arguments)))
    (when (or (< l positional-arity)
              (and (> l positional-arity) (not rest-arity)))
      (error (make-condition 'command-line-arity
               :name name
               :arguments arguments
               :rest-arity rest-arity
               :positional-arity positional-arity))))
  (let ((positional-arguments (subseq arguments 0 positional-arity))
        (rest-arguments (when rest-arity (subseq arguments positional-arity))))
    (apply function (append positional-arguments
                            (etypecase rest-arity
                              (null nil)
                              ((eql t) (list rest-arguments))
                              (keyword (list rest-arity rest-arguments)))
                            options))))

(defun handle-command-line (specification function
                            &key (positional-arity 0) (rest-arity nil) name
                            (command-line (get-command-line-arguments)))
  (multiple-value-bind (options arguments)
      (process-command-line-options specification command-line)
    (invoke-command-line-handler function options arguments
                                 :name name
                                 :positional-arity positional-arity
                                 :rest-arity rest-arity)))
