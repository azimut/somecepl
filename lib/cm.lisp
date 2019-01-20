(in-package :shiny)

;;--------------------------------------------------
;; CM helpers
;;--------------------------------------------------
;;
;; Reference:
;; https://ccrma.stanford.edu/courses/220b-winter-2006/cm/doc/dict/patterns-topic.html
;;
;; TODO:
;; (make-graph)
;; (make-markov)
;; (make-thunk)
;; (make-rewrite)
;; (make-transposer)
;; (make-chord)
;; (make-join)
;; (make-copier)

(defun make-cycle (elements &optional (for-elements 1 for-elements-p))
  (when elements ;; do not make a cycle of just nil
    (if for-elements-p
        (new cycle :of elements :for for-elements)
        (new cycle :of elements))))

(defun make-heap (elements &optional (for-elements 1 for-elements-p))
  (if for-elements-p
      (new heap :of elements :for for-elements)
      (new heap :of elements)))

(defun make-line (elements)
  "Useful for fade in/out, might be with (iota)"
  (new cm:line :of elements))

(defun make-rotation (elements &optional (for-elements 1 for-elements-p))
  "A constantly rotating pattern.
   > (next (make-rotation '(1 2 3 4)) 30)
   (1 2 3 4 2 3 4 1 3 4 1 2 4 1 2 3 1 2 3 4 2 3 4 1 3 4 1 2 4 1)"
  (if for-elements-p
      (new cm:rotation :of elements :for for-elements)
      (new cm:rotation :of elements)))

(defun make-accumulation (elements &optional (for-elements 1 for-elements-p))
  "For each item, generates all items up to and including the current item.
   The process starts over when all the items have been accumulated.
   > (cm:next (cm:new cm:accumulation :of '(1 2 3 4)) 10)
   (1 1 2 1 2 3 1 2 3 4)"
  (if for-elements-p
      (new cm:accumulation :of elements :for for-elements)
      (new cm:accumulation :of elements)))

(defun make-weighting (elements &optional (for-elements 1 for-elements-p))
  ;; try to add :weight keyword if only provided 2 elements
  ;; we push since order doesn't really matter...
  (let ((sane-elements '()))
    (loop for e in elements do
         (if (and (listp e) (= 3 (length e)))
             (push e sane-elements))
         (if (not (listp e))
             (push e sane-elements))
         (if (and (listp e) (= 2 (length e)))
             (push (list (first e)
                         :weight
                         (first (last e)))
                   sane-elements)))
    (if for-elements-p
        (new weighting :of sane-elements :for for-elements)
        (new weighting :of sane-elements))))

;; FIXME!!
(defun make-stutter
    (elements &optional (for 1))
  (cm:new cm:cycle
    :of elements
    :for
    (cm:new cm:cycle :of for)))

(defun make-palindrome (elements)
  (cm:new cm:palindrome :of elements :elide t))

(defun make-range (from to &optional (by 1))
  (cm:new cm:range :from from :to to :by by))

;; took from jazz.cm
(defun rancyc (data prob)
  (list (make-cycle data) :weight prob))

(defun markov-find-shortest (markov)
  (declare (markov markov))
  (let ((long-cycle (next markov 30)))
    (loop
       :for cycle :in long-cycle
       :with queue
       :while (not (position cycle queue))
       :finally (return queue)
       :do (push cycle queue))))

;;------------------------------------------------------------
;; TODO: sub-cycles, like (make-var '(4 2) '(1 2 (2 (3 4))))
;; Version that takes 2 lists
(defgeneric make-var (elements for)
  (:documentation "Returns a LIST of cycles and/or symbols.
FOR >1 is useful to stutter ELEMENTS.")
  (:method ((elements list) (for fixnum))
    (loop
       :for element :in elements
       :collect
         (if (and (= for 1)
                  (or (null element) (not (listp element))))
             element
             (cm:new cm:cycle :of element :for for))))
  (:method ((elements list) (for list))
    (loop
       :for element :in elements
       :for f :in for
       :collect
         (if (and (= f 1)
                  (or (null element) (not (listp element))))
             element
             (cm:new cm:cycle :of element :for f)))))

;; Version that takes 1+N arguments
(defgeneric make-cycles (for &rest rest)
  (:documentation "returns a list of cycles or symbols using FOR as the :for param
   tries to avoid creating cycles when FOR=1
   kind of useful to mimic stutter OR creating alternating patterns
   a'la () in FoxDot")
  (:method ((for fixnum) &rest rest)
    (if (= 1 for)
        (mapcar (lambda (x) (if (listp x)
                           (cm:new cm:cycle :of x :for for)
                           x))
                rest)
        (mapcar (lambda (x) (cm:new cm:cycle :of (ensure-list x) :for for))
                rest)))
  (:method ((for list) &rest rest)
    (loop
       :for f :in for
       :for r :in rest :collect
         (if (= 1 f)
             r
             (cm:new cm:cycle
               :of (ensure-list r)
               :for f)))))

