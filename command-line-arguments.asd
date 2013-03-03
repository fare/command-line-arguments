;;; -*- mode: lisp -*-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                  ;;;
;;; Free Software available under an MIT-style license. See LICENSE  ;;;
;;;                                                                  ;;;
;;; Copyright (c) 2008-2009 ITA Software, Inc.  All rights reserved. ;;;
;;;                                                                  ;;;
;;; Original authors: Francois-Rene Rideau                           ;;;
;;;                                                                  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defsystem :command-line-arguments
  :author ("Francois-Rene Rideau")
  :maintainer "Francois-Rene Rideau"
  :licence "MIT"
  :description "small library to deal with command-line arguments"
  :long-description "A library to abstract away the parsing of Unix-style command-line arguments"
  :depends-on (#-asdf3 :asdf-driver)
  :components
  ((:file "pkgdcl")
   (:file "argv" :depends-on ("pkgdcl"))
   (:file "parse" :depends-on ("pkgdcl"))
   (:file "help" :depends-on ("pkgdcl"))))
