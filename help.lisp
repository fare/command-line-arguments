#+xcvb (module (:depends-on ("pkgdcl")))

(in-package :command-line-arguments)

(defun split-sequence (sequence delimiter)
  (loop
     :with index = 0
     :for match = (position delimiter sequence :start index)
     :when (and match
                (not (= index match)))
     :collect (subseq sequence index match)
     :when match
     :do (setf index (1+ match))
     :unless (or match
                 (= index (length sequence)))
     :collect (subseq sequence index)
     :while match))

(defun show-option-help (specification &key (stream *standard-output*) sort-names docstring)
  ;; TODO: be clever when trying to align stuff horizontally
  (loop :with *print-right-margin* = (max (or *print-right-margin* 0) 100)
        :for spec :in specification :do
        (destructuring-bind (names &key negation documentation negation-documentation
                                   type optional list (initial-value nil initial-value-p) &allow-other-keys) spec
          (declare (ignorable negation documentation negation-documentation type optional list))
          (unless (consp names)
            (setf names (list names)))
          (flet ((option-names (names)
                   (let ((n (mapcar 'option-name names)))
                     (if sort-names
                       (stable-sort n #'< :key #'length)
                       n))))
            (when documentation
              (format stream
                      (if docstring
                          "~&* ~:@(~A~) (~A) ~@<~@;~{~A~^ ~}~@:>"
                          "~& ~32A ~8A ~@<~@;~{~A~^ ~}~@:>")
                      (if docstring
                          (car names)
                          (format nil "~{ ~A~}" (option-names names)))
                      (string-downcase type)
                      (split-sequence documentation #\Space))
              (format stream "~:[~*~; (default: ~S)~]~%" initial-value-p initial-value))
            (when negation-documentation
              (format stream " ~32A ~8A ~@<~@;~{~A~^ ~}~@:>~%"
                      (format nil "~{ ~A~}" (option-names (make-negated-names names negation)))
                      (string-downcase type)
                      (split-sequence negation-documentation #\Space)))))))
