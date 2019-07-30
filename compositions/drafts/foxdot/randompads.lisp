(in-package :shiny)

;; Completely offsounding cover of:
;; https://www.youtube.com/watch?v=k-v1Ibt1pW4
;; around 9:06
(csound-socket-send "start \"Mono\"")
(let ((note (make-weighting (iota 8)))
      (pan  (make-cycle '(.01 .99))))
  (defun p1 (time)
    (let ((d (between 1 7)))
      (csound-chnset (next pan) "Mono.pan")
      (csound-chnset (ilinvar '(500 5000) 128) "Mono.cut")
      (clc "MonoNote" (pc-relative (note :c4) (next note)
                                   (scale 0 'pentatonic))
           30 (* 2 d))
      (aat (+ time #[d b]) #'p1 it))))
(aat (tempo-sync #[1 b]) #'p1 it)
(defun p1 ())

(let ((p1 (fx-pat "(v-)-{-v}{v-}d---")))
  (defun d1 (time)
    (if (sometimes)
        (fx-play (fx-stutter (next p1) 4)
                 :amp .2 :dur 3 :downsamp 4
                 :sample (if (sometimes) 2 0))
        (fx-play (next p1) :amp .2 :downsamp 4
                           :sample (if (sometimes) 2 0)))
    (aat (+ time #[1 b]) #'d1 it)))
(aat (tempo-sync #[1 b]) #'d1 it)
(defun d1 ())

(let ((dur (make-cycle (mapcar (op (* 2 _)) (pdur 3 8)))))
  (defun b1 (time)
    (let ((d (next dur)))
      (clc "MonoNote" (transpose (ivar '(0 3 5 7) '(8 4 3 1)) 60)
           20 d)
      (aat (+ time #[d b]) #'b1 it))))
(aat (tempo-sync #[1 b]) #'b1 it)
(defun b1 ())

(let ((dur (make-cycle (pdur 3 8)))
      (var (var '(0 4) '(6 2)))
      (var2 (var '(0 1 2) .5)))
  (defun p2 (time)
    (let ((d (next dur)))
      (clc 23 (pc-relative (note :c4) (ivar '(0 4) '(6 2)) (scale 0 'minor))
           (* 10 (nth-beat 2 '(1 0))) d)
      (clc 23 (pc-relative (note :c4) (+ 2 (next var))
                           (scale 0 'minor))
           (* 10 (nth-beat 2 '(1 0))) d)
      (clc 23 (pc-relative (note :c4) (next var2)
                           (scale 0 'minor))
           (* 10 (nth-beat 2 '(1 0))) d)
      (aat (+ time #[d b]) #'p2 it))))
(aat (tempo-sync #[.75 b]) #'p2 it)
(defun p2 ())