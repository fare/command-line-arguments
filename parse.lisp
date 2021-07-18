;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                  ;;;
;;; Free Software available under an MIT-style license. See LICENSE  ;;;
;;;                                                                  ;;;
;;; Copyright (c) 2003-2011 ITA Software, Inc.  All rights reserved. ;;;
;;; Copyright (c) 2011-2012 Google, Inc.  All rights reserved.       ;;;
;;;                                                                  ;;;
;;; Original author: Francois-Rene Rideau                            ;;;
;;;                                                                  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#+xcvb (module (:depends-on ("pkgdcl")))

(in-package :command-line-arguments)

(defvar *command-line-options* nil
  "command-line options as parsed into a plist")

(defvar *command-line-option-specification* nil
  "the (prepared) specification for how to parse command-line options")

;; A raw specification is a list of individual option specifications.
;; An individual option specification is:
;; A single option name or a list of option names, and a keyword/value list of option options.
;; An option name is a single character #\x for short option -x,
;; or a string "foo" for long option --foo.
;; option options are:

;; :type for specifying a parameter type for the option.
;;  A type may be any of:
;;  NIL - the option takes no parameter.
;;  BOOLEAN - the option takes a boolean parameter.  The value can be true, false, yes, no, t, nil, y, n.
;;       If it's a long option, --no-foo is defined, too.
;;  STRING - the option takes a string as parameter
;;  INTEGER - the option takes an integer as parameter, interpreted in decimal.

;; :optional for allowing the option to have no parameter
;;  for a list, it allows the final list to be empty.

;; :action for specifying an action to do when the option is found
;;  an action may be a symbol to set, a function to call, nil to do nothing,
;;  or a keyword to push on the option plist.
;;  default action is to make a keyword from the first name.

;; :list
;;  the value is either T or a plist with keywords :initial-contents and :symbol.
;;  The :type must be integer or string.
;;  :symbol must be a special variable and
;;  :initial-contents must be a list (defaults to the provided initial-value).
;;  While the options are being processed, the special variable is bound to the
;;  initial contents, reversed.
;;  At the end of option processing, the finalizer reverses the list and calls
;;  the action, once.

;; :initial-value for specifying an initial value to call the action with
;;  before arguments are parsed. If the action is a keyword (the default)
;;  or symbol, this will provide you with a default value.
;;  :initial-value implies and overrides :optional.

;; TODO: add this feature, useful for verbose flags.
;; :count The value is a plist with keywords :initial-value and :symbol.
;;  A counter is initialized with initial-value (by default 0),
;;  incremented each time the option is invoked, decremented each time.
;;  Alternatively, if the option is given a numeric argument, the counter
;;  is set to the provided argument value.
;; TODO: add negation for lists with initial-value to allow for empty list.

;; :negation  Creates string called "no-XXX", or "disable-XXX" if the original name
;;  is "enable-XXX".

;; A *prepared* specification is an EQUAL-hash-table that maps option names to
;; a simple-vector #(action type optional) that specifies what to do when the option
;; is encountered in the command-line. It also includes three special entries for
;; keywords :local-symbol :local-values :finalizers that specify the local symbols
;; to bind when parsing options for this specification, the values to which to bind them,
;; and a list of finalizers to run after the parsing is done.

(defun make-option-action (p name
                           &key (action nil actionp) list optional
                           (initial-value nil initial-value-p) &allow-other-keys)
  "This is called for each option specification when preparing for parsing, and
   computes the action function to call (with optional value if provided)
   when the option is found on a command-line.
   P is the hash-table of actions.
   NAME is the first name of this option, a string or a character.
   The keywords are option options for this option specification."
  (let* ((actual-action (apply #'actual-action-from-spec name
                               (when actionp (list :action action)))))
    (when initial-value-p
      (setf optional t)
      (push (list 'command-line-action actual-action initial-value) (gethash :initializers p)))
    ;; If the :LIST option is not specified, just return the actual-action.
    (if (not list)
        actual-action
        (destructuring-bind (&key (initial-contents initial-value)
                                  (symbol (gensym (string-upcase name))))
            (and (listp list) list)
          (push symbol (gethash :local-symbols p))
          (push (reverse initial-contents) (gethash :local-values p))
          (flet ((register-finalizer ()
              (pushnew (list 'finalize-list name symbol optional actual-action)
                       (gethash :finalizers p)
                       :test 'equal)))
            (unless optional
              (register-finalizer))
            (cons (intern (string-upcase name) :keyword) #'(lambda (value)
                (when optional
                  (register-finalizer))
                (case value
                  ((nil) (set symbol nil))
                  ((t)   (error "Option ~A requires a parameter" (option-name name)))
                  (otherwise (push value (symbol-value symbol)))))))))))

(defun finalize-list (name symbol optional actual-action)
  (let ((value (symbol-value symbol)))
    (unless (or optional value)
      (error "No option ~A defined" (option-name name)))
    (command-line-action actual-action (reverse value))))

(defun actual-action-from-spec (name &key (action nil actionp))
  ;; If ACTION is not provided, it's a keyword named NAME.
  ;; If ACTION is provided, and this action is a function, nil, a keyword
  ;; or other symbol, then it's ACTION.
  ;; If ACTION is provided and is a list or the form (FUNCTION FOO)
  ;; (as e.g. read by #'FOO) then it's the symbol-function of FOO.
  ;; Otherwise, it's an error.
  ;; See COMMAND-LINE-ACTION below for how to interpret the results.
  ;; When ACTION is a function then return a cons of the keyword of
  ;; name and the action.
  (cond
    ((not actionp)
     (intern (string-upcase name) :keyword))
    ((or (functionp action) (symbolp action))
     ;; (keywordp action) and (null action) are implicitly included by symbolp
     (cons (intern (string-upcase name) :keyword) action))
    ((and (consp action) (eq 'function (car action))
          (consp (cdr action)) (null (cddr action)))
     (cons (intern (string-upcase name) :keyword)
           (symbol-function (cadr action))))
    (t
     (error "Invalid action spec ~S for option ~S" action name))))

(defun command-line-action (action &optional value)
  (etypecase action
    (null nil)
    (keyword  (setf *command-line-options*
		    (list* action value *command-line-options*)))
    (symbol   (set action value))
    ;; Function actions are saved as (keyword . function).
    (cons (setf *command-line-options*
                ;; Add the result of calling action to `*command-line-options*'.
                (list* (car action) (funcall (cdr action) value)
                       *command-line-options*)))))

(defun prepare-command-line-options-specification (specification)
  "Given a SPECIFICATION, return a hash-table mapping
   option names to a vector of
   the action function to call when encountering the option,
   the type of option arguments accepted, and
   whether the option is optional."
  (etypecase specification
    (hash-table specification)
    (list
     (let ((p (make-hash-table :test 'equal)))
       (dolist (spec specification)
         (destructuring-bind (names &rest option-options
                                    &key type optional list negation (initial-value nil initial-value-p)
                                    action documentation negation-documentation)
             spec
           (declare (ignorable action initial-value documentation negation-documentation))
           (when initial-value-p
             (setf optional t))
           (when list
             (unless (member type '(integer string))
               (error "option specification ~S wants list but doesn't specify string or integer" spec)))
           (let* ((namelist (if (listp names) names (list names)))
                  (firstname (car namelist))
                  (pos-action (apply 'make-option-action p firstname option-options)))
             ;; For each name of this spec, put an entry into the hash table
             ;; mapping that name to a vector of the action, the type, and
             ;; whether it's optional.
             (loop :with spec = (vector pos-action type (and optional (not list)))
                   :for name :in namelist :do
                   (setf (gethash name p) spec))
             ;; Deal with negation.
             (when (or (eq type 'boolean) list optional)
               (let ((neg-action #'(lambda (value)
                                     (command-line-action pos-action (not value))))
                     (neg-names (make-negated-names namelist negation)))
                 (loop :with spec = (vector neg-action nil nil nil)
                   :for name :in neg-names :do
                   (setf (gethash name p) spec)))))))
       p))))

(defun make-negated-names (namelist &optional negation)
  (let ((negation-list (if (listp negation) negation (list negation))))
    (loop :for name :in namelist
      :when (stringp name) :do
      (push (concatenate 'string "no-" name) negation-list)
      (when (and (<= 7 (length name))
                 (string= "enable-" (subseq name 0 7)))
        (push (concatenate 'string "disable-" (subseq name 7 nil))
              negation-list)))
    negation-list))

(defun command-line-option-specification (option)
  (let ((v (gethash option *command-line-option-specification*)))
    (if v (values t (svref v 0) (svref v 1) (svref v 2)) (values nil nil nil nil))))

(defun short-option-p (arg)
  "ARG is a string.  Is it like -X, but not -- ?"
  (check-type arg simple-string)
  (and (<= 2 (length arg))
       (char= #\- (schar arg 0))
       (char/= #\- (schar arg 1))))

(defun negated-short-option-p (arg)
  "ARG is a string.  Is it like +X ?"
  (check-type arg simple-string)
  (and (<= 2 (length arg))
       (char= #\+ (schar arg 0))))

(defun long-option-p (arg)
  "ARG is a string.  Is it like --XXX ?"
  (check-type arg simple-string)
  (and (<= 3 (length arg))
       (char= #\- (schar arg 0) (schar arg 1))))

(defun option-end-p (arg)
  (check-type arg simple-string)
  (string= arg "--"))

(defun option-like-p (arg)
  (check-type arg simple-string)
  (and (<= 2 (length arg))
       (or (char= #\- (schar arg 0))
           (char= #\+ (schar arg 0)))))

(defun option-name (option-designator)
  (etypecase option-designator
    ((eql #\Space) "  ") ; the same number of spaces just without the #\-
    (character (format nil "-~A" option-designator))
    (string    (format nil "--~A" option-designator))))

(defun coerce-option-parameter (option string type)
  "Given a STRING option argument and a TYPE of argument,
   return the argument value as a Lisp object.
   OPTION is the name of the option to which the argument is to be passed,
   for the sake of error messages."
  (flet ((fail ()
           (error "parameter ~A for option ~A not of type ~A" string (option-name option) type)))
    (ecase type
      ((nil)
       (error "option ~A does not take a parameter" (option-name option)))
      ((string)
       string)
      ((boolean)
       (cond
         ((member string '("true" "t" "1" "yes" "y") :test #'string-equal)
          t)
         ((member string '("false" "nil" "0" "no" "n") :test #'string-equal)
          nil)
         (t
          (fail))))
      ((integer)
       (multiple-value-bind (value end) (parse-integer string :junk-allowed t)
         (unless (and (integerp value) (= end (length string))) (fail))
         value)))))

(defun get-option-parameter (option type optional)
  (cond
    ((member type '(boolean t nil))
     t)
    ((and optional
          (or (null *command-line-arguments*)
              (option-like-p (car *command-line-arguments*))))
     t)
    (t
     (coerce-option-parameter option (pop *command-line-arguments*) type))))

(defun process-option (option validp action parameter type optional)
  (unless validp (error "Undefined option ~A" (option-name option)))
  (typecase parameter
    (null
     (unless (or (eq type 'boolean) optional)
       (error "Option ~A cannot be negated" (option-name option))))
    (string
     (setf parameter (coerce-option-parameter option parameter type)))
    (t
     (setf parameter (get-option-parameter option type optional))))
  (command-line-action action parameter))

(defun process-short-option (c &key negated)
  (multiple-value-bind (validp action type optional)
      (command-line-option-specification c)
    (process-option c validp action (not negated) type optional)))

(defun decompose-long-option-string (string)
  (let* ((separator (position #\= string :start 2))
         (name (subseq string 2 separator))
         (parameter (if separator (subseq string (1+ separator)) t)))
    (values name parameter)))

(defun process-long-option (s)
  (multiple-value-bind (name parameter) (decompose-long-option-string s)
    (multiple-value-bind (validp action type optional)
        (command-line-option-specification name)
      (process-option name validp action parameter type optional))))

(defun do-process-command-line-options ()
  "Remove all the options and values from *COMMAND-LINE-ARGUMENTS*.
   Process each option."
  (progv
      (gethash :local-symbols *command-line-option-specification*)
      (gethash :local-values *command-line-option-specification*)
    (loop :for (function . parameters) :in (gethash :initializers *command-line-option-specification*)
      :do (apply function parameters))
    (loop :for arg = (pop *command-line-arguments*) :do
      (cond
	((or (null arg) (option-end-p arg))
	 (return))
	((short-option-p arg)
	 (loop :for c :across (subseq arg 1 nil) :do
	   (process-short-option c)))
	((negated-short-option-p arg)
	 (loop :for c :across (subseq arg 1 nil) :do
	   (process-short-option c :negated t)))
	((long-option-p arg)
	 (process-long-option arg))
	(t
         (push arg *command-line-arguments*) ; put the first non-option back before we return.
	 (return))))
    (loop :for (function . parameters) :in (gethash :finalizers *command-line-option-specification*)
      :do (apply function parameters))))

(defun process-command-line-options (specification
                                     &optional (command-line *command-line-arguments*))
  "SPECIFICATION is a list as described above.
   COMMAND-LINE is the list of tokens to be parsed.
   Return two values:
   a list of alternating actions and values, and
   a list of the arguments remaining after the various specified options."
  (let*
      ((*command-line-option-specification*
        ;; The hash table describing each name.
	(prepare-command-line-options-specification specification))
       (*command-line-arguments*
        command-line)
       (*command-line-options* nil))
    (do-process-command-line-options)
    (values *command-line-options* *command-line-arguments*)))

(defmacro define-command (name args pre-help post-help &rest body)
  "Defines show-help-for-NAME, run-NAME, and NAME functions.

The `define-command' macro may be used to simultaneously define the
following three functions which are useful for defining a function
which may be invoked from the command line.  For example, the
following invocation of `define-command' on FOO results in:

    (define-command foo (noun verb &spec +command-line-spec+ &aux scratch)
      \"Usage: foo NOUN VERB [OPTIONS...]
    Do VERB to NOUN according to OPTIONS.\"
      #.(format nil \"~%Built with ~a version ~a.~%\"
                (lisp-implementation-type)
                (lisp-implementation-version))
      (declare (verbose))
      (when help (show-help-for-foo))
      #|...implementation...|#)

show-help-for-FOO
:   Prints help and option information for FOO to STDOUT.

    The docstring passed to `define-command' becomes the help text
    printed before options.  A second docstring passed as the fourth
    argument to `define-command' is printed after the options.

run-FOO
:   This function is meant to be used as a `defsystem' :ENTRY-POINT.
    It runs FOO on the command line arguments by invoking
    `handle-command-line'.

FOO
:   The &BODY passed to `define-command' becomes the body of the FOO
    function.  The positional required command line arguments become
    named arguments to FOO and the command line options passed in
    behind the &SPEC keyword in the argument list become keyword
    arguments to FOO.

    The macro-expanded prototype for FOO in this example would be the
    following (where all keyword arguments are option names from
    +command-line-spec+).

        (DEFUN FOO (NOUN VERB &KEY B CHECK VERBOSE WARN HELP VERSION &AUX SCRATCH))
"
  (labels ((plist-get (item list &key (test #'eql) &aux last)
             (loop :for element :in list :do
                (cond
                  (last (return element))
                  ((funcall test item element) (setf last t)))))
           (plist-drop-if (predicate list &aux last)
             (nreverse (reduce (lambda (acc element)
                                 (cond
                                   (last (setf last nil) acc)
                                   ((funcall predicate element)
                                    (setf last t) acc)
                                   (t (cons element acc))))
                               list :initial-value '())))
           (plist-drop (item list &key (test #'eql))
             (plist-drop-if (lambda (el) (funcall test item el)) list))
           (make-keyword (name)
             (intern (string name) :keyword))
           (take-while (pred seq)
             (if (and (not (null seq)) (funcall pred (car seq)))
                 (cons (car seq) (take-while pred (cdr seq)))
                 '()))

           (take-until (pred seq)
             (take-while (complement pred) seq))
           (drop-while (pred seq)
             (if (and (not (null seq)) (funcall pred (car seq)))
                 (drop-while pred (cdr seq))
                 seq))

           (drop-until (pred seq)
             (drop-while (complement pred) seq))
           (interleave (list sep &optional rest)
             (cond
               ((cdr list)
                (interleave (cdr list) sep (cons sep (cons (car list) rest))))
               (list (reverse (cons (car list) rest)))
               (t nil)))
           (mapconcat (func list sep)
             (apply #'concatenate 'string (interleave (mapcar func list) sep))))
    (let* ((package (package-name *package*))
           (command-line-specification (plist-get (intern "&SPEC" package) args))
           (rest-arg (let ((rest-arg (plist-get (intern "&REST" package) args)))
                       (when rest-arg (list (intern "&REST" package) rest-arg))))
           (positional-args (take-until
                             (lambda (el) (equal #\& (aref (symbol-name el) 0)))
                             (plist-drop (intern "&REST" package) args)))
           (aux-args (plist-drop
                      (intern "&REST" package)
                      (plist-drop
                       (intern "&SPEC" package)
                       (drop-until
                        (lambda (el) (equal #\& (aref (symbol-name el) 0)))
                        args))))
           (arity (length positional-args))
           (opts (eval command-line-specification))
           (keys (mapcar
                  (lambda (el)
                    (let ((name (intern (string-upcase (caar el))))
                          (default (plist-get :initial-value (cdr el))))
                      (if default
                          (list name default)
                          name)))
                  opts))
           (command-line-run-p (gensym "COMMAND-LINE-RUN-P"))
           (actions (remove nil
                      (mapcar
                       (lambda (el)
                         (let ((action (plist-get :action (cdr el)))
                               (name (intern (string-upcase (caar el)))))
                           (when action
                             `(locally (declare (special ,command-line-run-p))
                                (when (and (not ,command-line-run-p) ,name)
                                  (setf ,name (funcall ,action ,name)))))))
                       opts))))
      (flet ((symcat (&rest syms)
               (intern (mapconcat (lambda (el) (string-upcase (string el)))
                                  syms "-"))))
        `(locally (declare (special ,command-line-run-p))
           (defvar ,command-line-run-p nil
             ,(format nil "True if running ~a from the command line."
                      (symbol-name name)))
           (defun ,(symcat 'show-help-for name) ()
             ,(format nil "Print help information for `~a' and exit."
                      (symbol-name name))
             (format t ,(concatenate 'string
                          ;; Prepend usage information for command-line help.
                          (format nil "Usage: ~a [OPTION]... ~{~a~^ ~}~a~%~%"
                                  (string-downcase (symbol-name name))
                                  (mapcar #'symbol-name positional-args)
                                  ;; Add &REST argument to command line usage.
                                  (let ((rest-args (member '&rest args)))
                                    (if (and rest-args
                                             command-line-specification)
                                        (concatenate
                                            'string " ["
                                            (symbol-name (second rest-args))
                                            "]...")
                                        "")))
                          pre-help))
             (format t "~&~%OPTIONS:~%")
             (show-option-help ,command-line-specification :sort-names t)
             (format t ,post-help))

           (defun ,(symcat 'run name) ()
             ,(format nil "Run `~a' on `*command-line-arguments*'."
                      (symbol-name name))
             ;; Unless the main function takes rest arguments check for
             ;; exact number of positional arguments.
             (setf *lisp-interaction* nil)
             (let ((,command-line-run-p t))
               (declare (special ,command-line-run-p))
               (in-package ,(make-keyword package))
               (handler-case
                   (handle-command-line
                    ,command-line-specification ',name
                    :name ,(symbol-name name) ; Alternately (argv0).
                    :positional-arity ,arity ; Positional arguments.
                    :rest-arity
                    ,(if (member '&rest args)
                         (if command-line-specification
                             ;; NOTE: If both rest and
                             ;; keyword arguments convert
                             ;; the rest of the command
                             ;; line arguments into a
                             ;; keyword argument.
                             (make-keyword (second rest-arg))
                             ;; Otherwise keep/pass as a
                             ;; normal &rest argument.
                             t)
                         nil))
                 (command-line-arity (c)
                   ;; Don't print the arity requirement if the first
                   ;; argument looks like it's asking for help.
                   (unless (let ((it (car *command-line-arguments*)))
                             (and it (stringp it)
                                  (or (string= it "-h")
                                      (string= it "-?")
                                      (string= it "--help"))))
                     (format t "~A~%" c))
                   (,(symcat 'show-help-for name))
                   (return-from ,(symcat 'run name))))
               0))

           (defun ,name
               ,(append positional-args
                        (unless command-line-specification rest-arg)
                        (when keys
                          (cons '&key
                                ;; NOTE: See above note.  Convert &rest
                                ;; args to a keyword argument when other
                                ;; keyword arguments are given via the
                                ;; COMMAND-LINE-SPECIFICATION.
                                (if (and rest-arg command-line-specification)
                                    (cons (second rest-arg) keys)
                                    keys)))
                        aux-args)
             ,(with-output-to-string (str)
                (format str "~a~&~%Keyword arguments:~%" pre-help)
                (show-option-help opts :sort-names t :stream str :docstring t))
             ;; Don't accidentally place the actions before a DECLARE
             ;; form at the top of the function body.
             ,@(if (and actions
                        (listp (car body))
                        (eql 'declare (caar body)))
                   (append (list (car body))
                           actions
                           (cdr body))
                   body)))))))
