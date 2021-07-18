;;; -*- mode: lisp -*-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                  ;;;
;;; Free Software available under an MIT-style license. See LICENSE  ;;;
;;;                                                                  ;;;
;;; Copyright (c) 2008 ITA Software, Inc.  All rights reserved.      ;;;
;;;                                                                  ;;;
;;; Original authors: Francois-Rene Rideau                           ;;;
;;;                                                                  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defsystem "command-line-arguments"
  :author ("Francois-Rene Rideau")
  :maintainer "Eric Schulte"
  :licence "MIT"
  :description "small library to deal with command-line arguments"
  :long-description "A library to abstract away the parsing of Unix-style command-line arguments"
  :version "2.0.0"
  :depends-on (#-asdf3 :uiop)
  :components
  ((:file "pkgdcl")
   (:file "argv" :depends-on ("pkgdcl"))
   (:file "parse" :depends-on ("pkgdcl"))
   (:file "help" :depends-on ("pkgdcl")))
  :in-order-to ((test-op (test-op command-line-arguments/test))))

(defsystem "command-line-arguments/test"
  :depends-on (:command-line-arguments :alexandria :hu.dwim.stefil)
  :components ((:file "test"))
  :perform (test-op (o c) (call-function "command-line-arguments/test::test-suite")))
