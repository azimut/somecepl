(in-package #:shiny)
;;
;; Description: misc utils from foxdot
;;

;; https://github.com/Qirky/FoxDot/blob/master/FoxDot/lib/Utils/__init__.py
(defun pulses-to-durations (pulses)
  " Returns a list of durations based on pulses (1s) and blanks (0s).
    Data should be a list of [1,0] where 1 is a pulse."
  (loop :for i :in (cdr pulses)
        :for c :from 1
        :with seq = '()
        :with count = 1
        :finally (progn
                   (push count seq)
                   (return (reverse seq)))
        :do (if (= i 1)
                (progn
                  (push count seq)
                  (setf count 1))
                (incf count 1))))

;; https://github.com/Qirky/FoxDot/blob/master/FoxDot/lib/Patterns/Sequences.py
(defun pdur (n k &optional (start 0) (dur .25))
  "Returns the *actual* durations based on Euclidean rhythms (see PEuclid) where dur
        is the length of each step.
        ::
            >>> PDur(3, 8)
            P[0.75, 0.75, 0.5]
            >>> PDur(5, 16)
            P[0.75, 0.75, 0.75, 0.75, 1]"
  ;; If we have more pulses then steps, double the steps and decrease the duration
  (declare (type unsigned-byte start))
  (loop :while (> n k)
        :do (mulf k 2)
            (divf dur 2))
  (let ((pattern (pulses-to-durations (bjorklund n k))))
    (when (not (= 0 start))
      (setf pattern (alexandria:rotate pattern start)))
    (mapcar (lambda (x) (* dur x)) pattern)))

;; TODO: Player methods, they are like the pattern modifiers below
;;       but applied to a playing pattern.
;; https://github.com/Qirky/FoxDot/blob/master/FoxDot/lib/Players.py

;;--------------------------------------------------
;; TODO: Player Patterns
;;
;; <> - To separate patterns you want to play together.
;; () - Grouping characters in round brackets laces the pattern so
;;      that on each play through of the sequence of samples, the next
;;      character in the group's sample is played.
;; [] - Using square brackets will force the enclosed samples to
;;      played in the same time span as a single character e.g. `--[--]`
;;      will play two hi-hat hits at a half beat then two at a quarter
;;      beat.
;; {} - You can play a random sample from a selection by using curly
;;      braces in your Play String
;; || - play a sample NR , being x the sample symbol and N the number of
;;      the sample as in |xN| also possible to use () [] {}
;;--------------------------------------------------
;; Pattern methods
;; http://docs.foxdot.org/docs/patterns/pattern-methods/
;; https://github.com/Qirky/FoxDot/blob/master/FoxDot/lib/Patterns/Main.py
;;------------------------------
;; shuffle(n=1) =~
;; (cm:shuffle list) =~
;; (next (make-weighting '(1 2 3)) 10)
;;
;; Returns the pattern with it’s contents in a random order and n is
;; the number of permutations:
(defun fx-shuffle (l)
  (cm:shuffle l))
;;------------------------------
;; reverse() =~ (reverse)
;; Returns the pattern with its contents in reverse order. Nested
;; patterns / groups are *not* reversed.
(defun fx-reverse (l)
  (reverse l))
;;------------------------------
;; mirror()
;; Returns a pattern with its contents in reverse order, including
;; nested patterns and groups:
;;------------------------------
;; sort(*args, **kwargs) =~ (sort)
;; Returns a pattern with the values sorted in order. The args and
;; **kwargs are those that are supplied to Python’s builtin sorted
;; function but this returns a Pattern as opposed to a list.
(defun fx-sort (l f)
  (sort l f))
;;------------------------------
;; stutter(n=2)
;; Returns a new pattern with each value repeated n number of
;; times. If n is a pattern itself, then each value is repeated by the
;; number at the same index in the given pattern.
(defgeneric fx-stutter (l n)
  (:documentation
   "> (stutter '(1 2 3) 2)
    (1 1 2 2 3 3)

    > (stutter '(1 2 3 4) '(1 3))
    (1 2 2 2 3 4 4 4)")
  (:method ((l list) (n fixnum))
    (loop :for item :in l
          :append (loop :repeat n :collect item)))
  (:method ((l list) (n list))
    (loop :for item :in l
          :append (prog1 (loop :repeat (car n) :collect item)
                    (setf n (alexandria:rotate n)))))
  (:method (l (n fixnum))
    (repeat n (ensure-list l))))
;;------------------------------
;; arp(seq)
(defun fx-arp (l n)
  "Returns a new pattern with each item repeated len(seq) times and
   incremented by the values in seq. Useful for arpeggiating.
   > (arp '(0 1 2 3) '(0 4))
   (0 4 1 5 2 6 3 7)"
  (declare (type list n l))
  (loop :for note :in l
        :append (loop :for offset :in n :collect (+ note offset))))
;;------------------------------
;; splice(seq, *seqs)
;; Takes one or more patterns to “splice” into the original
;; pattern. The new pattern returned is made up of the values from the
;; original and given sequences in an alternated fashion.
;; https://github.com/vseloved/rutils/blob/master/core/list.lisp
(defun fx-splice (list &rest lists)
  "Return a list whose elements are taken from LIST and each of LISTS like this:
   1st of list, 1st of 1st of lists,..., 1st of last of lists, 2nd of list,...
   > (splice '(0 1 2 3) '(a b c))
   (0 A 1 B 2 C)"
  (apply #'mapcan (lambda (&rest els)
                    els)
         list lists))
;;------------------------------
;; invert()
(defun fx-invert (l)
  "Creates an inverted version of pattern by subtracting its values
   from the largest value in the pattern such that the largest value
   in the pattern becomes the smallest (and vice versa) and the
   difference between other values and the min/max are swapped:
   > (fx-invert '(2 5 1 11))
   (9 6 10 0)"
  (declare (type list l))
  (let ((max (extremum l #'>)))
    (loop :for item :in l
          :collect (- max item))))
;;------------------------------
;; shufflets(n = 4)
(defun fx-shufflets (l n)
  "Returns a new pattern that contains the original pattern as a
   PGroup in random order of length n.
   > (fx-shufflets '(1 2 3 4) 3)
   ((4 1 3 2) (3 1 4 2) (3 2 1 4))"
  (declare (type list l) (type unsigned-byte n))
  (loop :repeat n
        :collect (cm:shuffle l)))
;;------------------------------
;; pivot(i)
(defun fx-pivot (l n)
  "Returns a new pattern that is a reversed version of the original
   but then rotated such that the element at index i is still in the
   same place."
  (declare (type list l) (type unsigned-byte n))
  (let* ((len (length l))
         (mid (/ len 2)))
    (if (> n mid)
        (progn
          (setf n (1- (- len n)))
          (setf l (rotate (reverse l) (1+ (* 2 (mod n len))))))
        (setf l (reverse (rotate l (1+ (* 2 (mod n len)))))))
    l))
;;------------------------------
;; accum(n=None)
(defun fx-accum (l &optional (n (length l)))
  "Returns a pattern that is equivalent to the list of sums of that
   pattern up to that index (the first value is always 0). The
   argument n specifies the length of the new pattern. When n is None
   then the new pattern takes the length of the original.
   > (fx-accum '(1 2 3 4) 8)
   (0 1 3 6 10 11 13 16)"
  (declare (type list l) (type unsigned-byte n))
  (loop :for i :in (repeat (1- n) l)
        :with s = '(0)
        :with prev = 0
        :finally (return (reverse s))
        :do (let ((current (+ i prev)))
              (push current s)
              (setf prev current))))
;;------------------------------
;; stretch(size)
(defun fx-stretch (l n)
  "Returns a pattern that is repeated until the length is equal to size."
  (declare (type list l) (type unsigned-byte n))
  (repeat n l))
;;------------------------------
;; trim(size)
(defun fx-trim (l n)
  "Like stretch but the length cannot exceed the length of the
   original pattern."
  (declare (type list l) (type unsigned-byte n))
  (repeat (min (length l) n) l))
;;------------------------------
;; ltrim(size)
(defun fx-itrim (l n)
  "Like trim but removes items from the start of the pattern, not the end."
  (declare (type list l) (type unsigned-byte n))
  (reverse (repeat (min (length l) n) (reverse l))))
;;------------------------------
;; loop(n)
;;------------------------------
;; duplicate(n)
;; Like loop but retains the nested patterns such that the first value
;; in the nests are used on the first iteration through the duplicated
;; sequence etc.
(defun fx-duplicate (l n)
  "Repeats the pattern n times. Useful when chaining together multiple
   patterns. Nested patterns are taken into consideration when
   looping."
  (let* ((len (length l))
         (n2  (* len n)))
    (repeat n2 l)))
;;------------------------------
;; iter
;; Like loop but does not take nested patterns into account when
;; calculating the length.
;;------------------------------
;; swap(n)
;; Swaps the places of values in the pattern. When n is 2 then values
;; next to each other are swapped, when n is 3 then values next but 1
;; are swapped, and so on.
;; FIXME: returns a shorter list than FoxDot
(defun fx-swap (l n)
  (loop :for d :from 0 :by n
        :for u :from n :by n :to (length l)
        :append (reverse (subseq l d u))))
;;------------------------------
;; rotate(n)
;; Returns a pattern with the original pattern’s values shifted left
;; in order by n number of places. Negative numbers shift the values
;; right.

(defgeneric fx-rotate (l n)
  (:method ((l sequence) (n fixnum))
    (alexandria:rotate l n))
  (:method ((l vector) (n list))
    (loop :for rot :in n
          :append (coerce (alexandria:rotate l (- rot))
                          'list)))
  (:method ((l list) (n list))
    (loop :for rot :in n
          :append (alexandria:rotate l (- rot)))))
;;------------------------------
;; sample(n) =~ (choose-n) =~ (pickn)
(defun fx-sample (l n)
  "Returns an n-length pattern with randomly selected values from the
   original pattern."
  (subseq (alexandria:shuffle l) 0 n))
;;------------------------------
;; palindrome()
;; Appends the reverse of a pattern onto itself such that is creates a
;; palindrome of numbers.
(defun fx-palindrome (l)
  (appendf l (reverse l)))
(defun fx-palindrome2 (l)
  (appendf l (reverse (butlast l))))
;;------------------------------
;; alt(seq)
;; Replaces the pattern with that of seq. Useful if you want to use an
;; alternate pattern and assign it using the every method.
;;
;; !???
;;------------------------------
;; norm()
;; Returns a pattern with all the values normalised such that every
;; value in the new pattern is between 0 and 1.
(defun fx-norm (l)
  (let ((max (* 1f0 (extremum l #'>))))
    (loop :for item :in l :collect
             (/ item max))))
;;------------------------------
;; undup()
;; Removes any consecutive duplicate values so that there are no
;; repeated values in the pattern.
(defun fx-undup (l)
  (remove-duplicates l))
;;------------------------------
;; limit(func, value)
;; Returns a new pattern generated by appending values from the
;; original until func(pattern) exceeds value. The func argument must
;; be a valid function, such as len or sum.
;;------------------------------
;; replace(sub, repl)
;; Returns a new pattern with values equal to sub replaced with repl.
(defun fx-replace (l sub repl)
  (substitute repl sub l))
;;------------------------------
;; submap(mapping)
;; Similar to replace but takes a dictionary of sub to repl values to
;; replace multiple items.
;; FIXME? do it backwars? Iterate and then lookup?
(defun fx-submap (l alist)
  (declare (type list l) (type cons alist))
  (loop :for (sub . repl) :in alist
        :collect (setf l (substitute repl sub l)))
  l)
;;------------------------------
;; layer(method, *args, **kwargs)
;; Zips the original pattern with itself but with method called on
;; itself, which must be a string name of a valid pattern method
;; (similar to Player.every). However, the method argument can also be
;; a function (example below).
;;------------------------------
;; every(n, method, *args, **kwargs)
;; Repeats the original pattern n times and applies the Pattern method
;; (specified as a string) on the last repetition with args and kwargs
;; supplied.
;;------------------------------
;; map(callable)
;; Returns a new Pattern with the callable argument called on every
;; item in the pattern.
;;------------------------------
;; extend(seq)
;; Extends the Pattern with seq in place i.e. it returns None as
;; opposed to a new Pattern. This is more efficient than the concat
;; method for combining multiple sequences into one Pattern.
;;------------------------------
;; concat(seq)
;; Returns a new Pattern with the contents of seq appended onto the
;; end of the original Pattern. The special __or__ method (which uses
;; the | syntax) also calls this method.
;;------------------------------
;; zip(seq)
;; “Zipping” is the process of combining two sequences into one where
;; each element is a group that contains the items from each sequence
;; at the same index. If the sequences are of different lengths then
;; then they are zipped up to the length of the lowest common multiple
;; of both lengths.
;;------------------------------
;; offadd(value, dur=0.5)
;; Adds value to the Pattern, zips with the original, and delays the
;; zipped value by dur using the PGroupPrime class.
;;------------------------------
;; offmul(value, dur=0.5)
;; Similar to offadd but multiplies the values as opposed to adding.
;;------------------------------
;; offlayer(method, dur=0.5, *args, **kwargs)
;; Similar to offadd and offmul but uses a user-specified method or
;; function instead of addition/multiplication. The method argument
;; must be a valid name of a Pattern method as a string or a callable
;; object such as a function. Any extra arguments or keyword arguments
;; are supplied after the duration to delay the layer, therefore
;; duration must be supplied if supplying arguments as part of *args.
;;------------------------------
;;  amen()
;; Replicates the rhythm and order of the famous “amen break” based on
;; a kick-drum, hi-hat, snare-drum, hi-hat sequence. Listen to the
;; example below:

;; (defun amen (pat &optional (size 2))
;;   "merges and laces the first and last two items such that a
;;    drum pattern \"x-o-\" would become \"(x[xo])-o([-o]-)\""
;;   (let ((new '()))
;;     (loop :for n :in (myrange (lcm (length pat) 4))
;;        :do )))



;; TimeVar has a series of values that it changes between after a
;; pre-defined number of beats and is created using a var object with
;; the syntax
;; var([list_of_values],[list_of_durations]).
;;
;; TODO: subvars on vars parameter. var([0,5,2[3,6]],[8,6,1,1])
(defun var (vars n-beats)
  "Returns a function, that returns a value from VARS, a new one if N-BEATS have passed.
   > (defvar *var1* (var '(1 2) 4))
   > (funcall *var1*)
   1
   > (cm:next *var1*)
   2"
  (declare (type list vars))
  (let ((start-beat (beat))
        (current-beat  0d0)
        (elapsed-beats 0d0)
        (var-index  0)
        (beat-index 0)
        (beats (ensure-list n-beats)))
    (lambda ()
      (setf current-beat  (beat))
      (setf elapsed-beats (- current-beat start-beat))
      ;;
      (when (> elapsed-beats (nth beat-index beats))
        (setf start-beat current-beat)
        (setf var-index  (mod (1+ var-index)  (length vars)))
        (setf beat-index (mod (1+ beat-index) (length beats))))
      (nth var-index vars))))

;; Like csound nth-beat but accepts 2 lists
(defun ivar (vars at-beats)
  "Inplace var()"
  (let* ((vars      (ensure-list vars))
         (n-vars    (length vars))
         (at-beats  (repeat n-vars (ensure-list at-beats)))
         (beat      (beat))
         (sum       (reduce #'+ at-beats))
         (curr-beat (mod beat sum))
         (sum-beats (loop :for i :in at-beats :summing i :into all :collect all))
         (var-pos   (position-if (lambda (n) (< curr-beat n))
                                 sum-beats)))
    (nth var-pos vars)))

(defun linvar (vars n-beats)
  (declare (type list vars))
  (let ((start-beat (beat))
        (current-beat  0d0)
        (elapsed-beats 0d0)
        (var-index  0)
        (beat-index 0)
        (beats (ensure-list n-beats)))
    (lambda ()
      (setf current-beat  (beat))
      (setf elapsed-beats (- current-beat start-beat))
      ;;
      (when (> elapsed-beats (nth beat-index beats))
        (setf start-beat current-beat)
        (setf var-index  (mod (1+ var-index)  (length vars)))
        (setf beat-index (mod (1+ beat-index) (length beats))))
      (alexandria:lerp (/ elapsed-beats (nth beat-index beats))
                       (nth 0 vars)
                       (nth 1 vars)))))

;; FIXME: fix lerp from 0-1 to 0-1-0
(defun ilinvar (vars n-beat)
  "Inplace linvar()"
  (declare (type list vars)
           (type number n-beat))
  (assert (length= 2 vars))
  (let ((beat (mod (beat) n-beat)))
    (coerce (alexandria:lerp (/ beat n-beat)
                             (nth 0 vars)
                             (nth 1 vars))
            'single-float)))

(defun often ()
  (= (mod (beat) 32)
     (serapeum:random-in-range 1 8)))

(defun sometimes ()
  (= (mod (beat) 32)
     (serapeum:random-in-range 8 32)))

(defun rarely ()
  (= (mod (beat) 32)
     (serapeum:random-in-range 32 64)))

;;.sometimes("amp.trim", 3)

;; def often(self, *args, **kwargs):
;; """ Calls a method every 1/2 to 4 beats using `every` """
;; return self.every(PRand(1, 8)/2, *args, **kwargs)

;; def sometimes(self, *args, **kwargs):
;; """ Calls a method every 4 to 16 beats using `every` """
;; return self.every(PRand(8, 32)/2, *args, **kwargs)

;; def rarely(self, *args, **kwargs):
;; """ Calls a method every 16 to 32 beats using `every` """
;; return self.every(PRand(32, 64)/2, *args, **kwargs)

;; def every(self, n, cmd, args=()):
;;   def event(f, n, args):
;;     f(*args)
;;     self.schedule(event, self.now() + n, (f, n, args))
;;     return
;;   self.schedule(event, self.now() + n, args=(cmd, n, args))
;;   return

