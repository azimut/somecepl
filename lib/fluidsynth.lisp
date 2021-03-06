(in-package #:shiny)

(defvar *settings* (fluidsynth:new-settings
                    `(("synth.polyphony" 128)
                      ("synth.midi-channels" 32)
                      ("synth.sample-rate" ,*sample-rate*)
                      ("audio.sample-format" "float"))))

(defvar *synth* (fluidsynth:new *settings*))

(dsp! fluid-test ((synth fluidsynth:synth))
  (with ((len   (block-size))
         (left  (make-f32-array len))
         (right (make-f32-array len)))
    (fluidsynth:write-float synth len left 0 1 right 0 1)
    (foreach-frame
      (out (f32-ref left  current-frame)
           (f32-ref right current-frame)))))

;; Adding filters to output from fluidsynth.
;;----------------------------------------
;; Due the output is single-float I cannot apply a filter directly
;; So i dump the channels to buses. Then use a second dsp to filter.
;; Trying to implement:
;; https://sourceforge.net/p/incudine/mailman/message/36266377/

;; I use this when rt-block-size != 1, otherwise just use (bus) directly
(define-vug input-bus ((channel fixnum))
  (bus
   (the fixnum
        (+ (the fixnum (* current-frame 2))
           channel
           2))))

(dsp! fluid-in-down ((synth fluidsynth:synth))
  (with ((len   (block-size))
         (left  (make-f32-array len))
         (right (make-f32-array len)))
    (fluidsynth:write-float synth len left 0 1 right 0 1)
    (foreach-frame
      (setf (input-bus 0) (f32-ref left  current-frame)
            (input-bus 1) (f32-ref right current-frame)))))
;; (fluid-in-down *synth*)
;; (fluid-out-down)
;; (free (node 0))
;; (lvc-mono )
;; (p (now) 60 60 1 0)
;; (incudine.vug:lv2->vug "http://invadarecords.com/plugins/lv2/compressor/mono"
;;                        lvc-mono)
;; (incudine.vug:lv2->vug "http://invadarecords.com/plugins/lv2/compressor/stereo"
;;                        lvc-stereo)
;; (dsp! fluid-out-down ()
;;   (foreach-frame
;;     (foreach-channel
;;       (with-samples ((c (input-bus current-channel)))
;;         (cout c)))))

;;--------------------------------------------------

(defgeneric p (time pitch velocity duration channel &key pan))

;; Stop reusing p here. WHY?
(defmethod p ((time double-float) (pitch list) (velocity fixnum) (duration number) (channel fixnum) &key pan)
  "Play chord of notes"
  (mapc (lambda (p)
          (declare (fixnum p))
          (when (and (> p 0) (> duration 0) (> velocity 0))
            (when pan (fpan channel pan))
            (at time #'fluidsynth:noteon *synth* channel p velocity)
            (at (+ time (calc-beats duration)) #'fluidsynth:noteoff *synth* channel p)))
        pitch))
(defmethod p ((time double-float) (pitch list) (velocity fixnum) (duration list) (channel fixnum) &key pan)
  "Play chord of notes, with provided durations"
  (mapc (lambda (p d)
          (declare (fixnum p))
          (when (and (> p 0) (> d 0) (> velocity))
            (when pan (fpan channel pan))
            (at time #'fluidsynth:noteon *synth* channel p velocity)
            (at (+ time (calc-beats d)) #'fluidsynth:noteoff *synth* channel p)))
        pitch
        duration))
(defmethod p ((time double-float) (pitch list) (velocity fixnum) (duration number) (channel list) &key pan)
  "Play chord of notes, on provided channels"
  (mapc (lambda (p c)
          (declare (fixnum p c))
          (p time p velocity duration c))
        pitch
        channel))
(defmethod p ((time double-float) (pitch fixnum) (velocity fixnum) (duration number) (channel fixnum) &key pan)
  "Play given pitch"
  (when (and (< 0 pitch 127)
             (> duration 0)
             (> velocity 0))
    (when pan
      (fluidsynth:cc *synth* channel 10 (alexandria:clamp pan 0 127)))
    (at time #'fluidsynth:noteon *synth* channel pitch velocity)
    (at (+ time (calc-beats duration)) #'fluidsynth:noteoff *synth* channel pitch))
  pitch)
(defmethod p ((time double-float) (pitch fixnum) (velocity fixnum) (duration symbol) (channel fixnum) &key pan)
  "Play given pitch, at CM duration/rythm"
  (let ((d (cm:rhythm duration)))
    (when (and (> d 0) (> velocity 0))
      (at time #'fluidsynth:noteon *synth* channel pitch velocity)
      (at (+ time (calc-beats d)) #'fluidsynth:noteoff *synth* channel pitch)))
  pitch)
(defmethod p ((time double-float) (pitch symbol) (velocity fixnum) (duration symbol) (channel fixnum) &key pan)
  "Play given note on american notation, at CM duration/rhythm"
  (unless (and (eql :_ pitch) (eql 'cm::r pitch) (eql NIL pitch))
    (let ((n (if (keywordp pitch) (note pitch) (cm:keynum pitch)))
          (d (cm:rhythm duration)))
      (declare (fixnum n))
      (when (and (> d 0) (> velocity 0))
        (at time #'fluidsynth:noteon *synth* channel n velocity)
        (at (+ time (calc-beats d)) #'fluidsynth:noteoff *synth* channel n))))
  pitch)
(defmethod p ((time double-float) (pitch symbol) (velocity fixnum) (duration number) (channel fixnum) &key pan)
  "Play given note on american notation"
  (when (and (> duration 0)
             (not (eql NIL pitch))
             (not (eql :_ pitch))
             (not (eql 'cm::r pitch))
             (> velocity 0))
    (let ((n (if (keywordp pitch) (note pitch) (cm:keynum pitch))))
      (declare (fixnum n))
      (at time #'fluidsynth:noteon *synth* channel n velocity)
      (at (+ time (calc-beats duration)) #'fluidsynth:noteoff *synth* channel n)))
  pitch)

;;--------------------------------------------------
;; TODO:
;; - add one that takes a single note and multiple velocities,
;;   useful for cycles that last whole bars.
;; - use a more generic macro so i can use the same pattern for midi/jack

(defgeneric pa (time notes velocity duration channel offset)
  (:documentation "Play the given notes as an arpeggio"))

;; Single note, single all
(defmethod pa ((time double-float) (notes number) (velocity fixnum) (duration number) (channel fixnum) (offset number))
  (when (>= offset 0)
    (p (+ time (calc-beats offset)) notes velocity duration channel))
  notes)

;; Single note, multiple other things
(defmethod pa ((time double-float) (notes number) (velocity list) (duration number) (channel fixnum) (offset number))
  (let* ((lnotes  (length velocity))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (map nil (lambda (v o)
               (declare (fixnum v))
               (p (+ time (calc-beats o)) notes v duration channel))
         velocity
         offsets)
    notes))
(defmethod pa ((time double-float) (notes number) (velocity fixnum) (duration list) (channel fixnum) (offset number))
  (let* ((lnotes  (length duration))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (map nil (lambda (d o)
               (p (+ time (calc-beats o)) notes velocity d channel))
         duration
         offsets)
    notes))
(defmethod pa ((time double-float) (notes number) (velocity fixnum) (duration number) (channel fixnum) (offset list))
  (map nil (lambda (o)
             (when (>= o 0)
               (p (+ time (calc-beats o)) notes velocity duration channel)))
       offset)
  notes)
(defmethod pa ((time double-float) (notes number) (velocity list) (duration number) (channel fixnum) (offset list))
  (map nil (lambda (v o)
             (declare (fixnum v))
             (when (>= o 0)
               (p (+ time (calc-beats o)) notes v duration channel)))
       velocity
       offset)
  notes)
(defmethod pa ((time double-float) (notes number) (velocity fixnum) (duration list) (channel fixnum) (offset list))
  (map nil (lambda (d o)
             (when (>= o 0)
               (p (+ time (calc-beats o)) notes velocity d channel)))
       duration
       offset)
  notes)

;; Multiple notes
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration number) (channel fixnum) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o)
            ;; (declare (fixnum n) (number o))
            (p (+ time (calc-beats o)) n velocity duration channel))
          notes
          offsets)))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration number) (channel list) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o c)
            (declare (fixnum c))
            (p (+ time (calc-beats o)) n velocity duration c))
          notes
          offsets
          channel)))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration number) (channel fixnum) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o v)
            (declare (fixnum v))
            (p (+ time (calc-beats o)) n v duration channel))
          notes
          offsets
          velocity)))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration number) (channel list) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o v c)
            (declare (fixnum v c))
            (p (+ time (calc-beats o)) n v duration c))
          notes
          offsets
          velocity
          channel)))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration list) (channel fixnum) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o d)
            ;;(declare (fixnum n))
            (p (+ time (calc-beats o)) n velocity d channel))
          notes
          offsets
          duration)))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration list) (channel list) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o c d)
            (declare (fixnum c))
            (p (+ time (calc-beats o)) n velocity d c))
          notes
          offsets
          channel
          duration)))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration list) (channel fixnum) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o v d)
            (declare (fixnum v))
            (p (+ time (calc-beats o)) n v d channel))
          notes
          offsets
          velocity
          duration)))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration list) (channel list) (offset number))
  (let* ((lnotes  (length notes))
         (offsets (loop :for i :from 0 :by offset :collect i :repeat lnotes)))
    (mapc (lambda (n o v c d)
            (declare (fixnum v c))
            (p (+ time (calc-beats o)) n v d c))
          notes
          offsets
          velocity
          channel
          duration)))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration number) (channel fixnum) (offset list))
  (mapc (lambda (n o)
          ;;(declare (fixnum n))
          (p (+ time (calc-beats o)) n velocity duration channel))
        notes
        offset))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration number) (channel list) (offset list))
  (mapc (lambda (n o c)
          (declare (fixnum c))
          (p (+ time (calc-beats o)) n velocity duration c))
        notes
        offset
        channel))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration number) (channel fixnum) (offset list))
  (mapc (lambda (n o v)
          (declare (fixnum v))
          (p (+ time (calc-beats o)) n v duration channel))
        notes
        offset
        velocity))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration number) (channel list) (offset list))
  (mapc (lambda (n o v c)
          (declare (fixnum v c))
          (p (+ time (calc-beats o)) n v duration c))
        notes
        offset
        velocity
        channel))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration list) (channel fixnum) (offset list))
  (mapc (lambda (n o d)
          ;;(declare (fixnum n))
          (p (+ time (calc-beats o)) n velocity d channel))
        notes
        offset
        duration))
(defmethod pa ((time double-float) (notes list) (velocity fixnum) (duration list) (channel list) (offset list))
  (mapc (lambda (n o c d)
          (declare (fixnum c))
          (p (+ time (calc-beats o)) n velocity d c))
        notes
        offset
        channel
        duration))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration list) (channel fixnum) (offset list))
  (mapc (lambda (n o v d)
          (declare (fixnum v))
          (p (+ time (calc-beats o)) n v d channel))
        notes
        offset
        velocity
        duration))
(defmethod pa ((time double-float) (notes list) (velocity list) (duration list) (channel list) (offset list))
  (mapc (lambda (n o v c d)
          (declare (fixnum v c))
          (p (+ time (calc-beats o)) n v d c))
        notes
        offset
        velocity
        channel
        duration))

;;--------------------------------------------------

(defun freset ()
  "reset all the things! (programs and synths)"
  (fluidsynth:system-reset *synth*))

(defun off-with-the-notes (&optional (max-channels 32))
  "turn off all the notes"
  (dotimes (chan max-channels)
    (fluidsynth:all-notes-off *synth* chan)))

;; ---------------------------------------------------

;; http://midi.teragonaudio.com/tech/midispec/pressure.htm
(defun fpress (channel pressure)
  "Set the MIDI channel pressure controllre value.
   a.k.a wibbly-woobly
   0>=pressure>=127"
  (declare (type (integer 0 127) pressure))
  (fluidsynth:channel-pressure *synth* channel pressure))

;; http://midi.teragonaudio.com/tech/midispec.htm
(defun fsens (channel sens)
  "Set MIDI pitch wheel (aka sensitivity) on a MIDI channel.
   0>=sens>=72"
  (declare (type (integer 0 72) sens))
  (fluidsynth:pitch-wheel-sens *synth* channel sens))

;; NOTE: I think the default is correct...sounds like it
;; http://www.moforte.com/geoShredAssets2.0/help/pitchBendRange.html
;; "If 8192 equals 12 semitones, then one semitone is pitchbend value  8192 / 12 = 682.66667."
(defun fpitch (channel &optional (bend 8192))
  "Set the MIDI pitch bend controller value on a MIDI channel.
   0>=bend>=16383"
  (declare (type (integer 0 16383) bend))
  (fluidsynth:pitch-bend *synth* channel bend))

;; From FoxDot
(defun fspread (channel left-p &optional (semitones .125))
  (declare (type boolean left-p))
  (if left-p (fpan channel 0) (fpan channel 127))
  (fpitch channel (+ 8192 (round (* semitones (/ 8192 12))))))

;; ---------------------------------------------------

(let ((enabled 0))
  (defun fchorus-toggle ()
    (setf enabled (mod (1+ enabled) 2))
    (fluidsynth:set-chorus-on *synth* enabled)
    (if (zerop enabled) :DISABLED :ENABLED)))

(defun fchorus (&key (nr        3 nr-set)
                     (level 2.0d0 level-set)
                     (speed 0.3d0 speed-set)
                     (depth 8.0d0 depth-set)
                     (mode      0 mode-set))
  (assert (and (<= 0 nr 99)
               (<= 0d0 level 10d0)
               (<= 0.29d0 speed 5.0d0)
               (<= 0.0d0 depth 21.0d0)
               (or (= mode 0) (= mode 1))))
  (when (or nr-set level-set speed-set
            depth-set mode-set)
    (fluidsynth:set-chorus *synth*
                           nr level speed
                           depth mode)))

;;--------------------------------------------------

(let ((enabled 0))
  (defun freverb-toggle ()
    (setf enabled (mod (1+ enabled) 2))
    (fluidsynth:set-reverb-on *synth* enabled)
    (if (zerop enabled) :DISABLED :ENABLED)))

(defun freverb (&key (roomsize 0.2d0 roomsize-p)
                     (damp     0.0d0 damp-p)
                     (width    0.5d0 width-p)
                     (level    0.9d0 level-p))
  (when (or roomsize-p damp-p width-p level-p)
    (fluidsynth:set-reverb *synth* roomsize damp width level)))

;; fluid_synth.c
(defun freverb-preset (preset)
  (case preset
    (1 (freverb :roomsize 0.2d0 :damp 0.0d0 :width 0.5d0 :level 0.9d0))
    (2 (freverb :roomsize 0.4d0 :damp 0.2d0 :width 0.5d0 :level 0.8d0))
    (3 (freverb :roomsize 0.6d0 :damp 0.4d0 :width 0.5d0 :level 0.7d0))
    (4 (freverb :roomsize 0.8d0 :damp 0.7d0 :width 0.5d0 :level 0.6d0))
    (5 (freverb :roomsize 0.8d0 :damp 1.0d0 :width 0.5d0 :level 0.5d0))
    (6 (freverb :roomsize 0.6d0 :damp 0.1d0 :width 0.9d0 :level 1d0))
    (t (format nil "choose a value between 1-6 dummy"))))

;;--------------------------------------------------

(defun fp (channel program &optional (bank 0 bank-set))
  "short-hand to set the fluidsynth channel to program"
  (declare (type integer channel program bank))
  (when bank-set
    (fluidsynth:bank-select *synth* channel bank))
  (fluidsynth:program-change *synth* channel program))

(defun all-piano (&optional (program 0) (max-channels 32))
  "set all the midi channels to PROGRAM"
  (dotimes (chan max-channels)
    (fluidsynth:program-change *synth* chan program)))

(defun try-sounds (time chan sf &optional (beats 8) (bank 0 bank-set))
  "helper to iterate over programs on a soundfont to test sounds"
  (print sf)
  (when bank-set
    (fluidsynth:bank-select *synth* chan bank))
  (fluidsynth:program-change *synth* chan (mod sf 100))
  (aat (+ time beats) #'try-sounds it chan (1+ sf) beats))

;;--------------------------------------------------

(defun fg (gain)
  "short-hand to set the gain on fluidsynth"
  (declare (type float gain))
  (setf (fluidsynth:setting *settings* "synth.gain")
        gain))

;;--------------------------------------------------

(defun fpan (channel pan)
  (declare (type (integer 0 127) pan))
  (fluidsynth:cc *synth* channel 10 pan))

(defun fvol (channel vol)
  (declare (type (integer 0 127) vol))
  (fluidsynth:cc *synth* channel 7 vol))

(defun all-pan (&optional (pan 64) (max-channels 32))
  "Set PAN on all channels"
  (declare (type (integer 0 127) pan))
  (dotimes (channel max-channels)
    (fluidsynth:cc *synth* channel 10 pan)))

(defun fstart (&optional (id 777))
  "starts fluidsynth dsp! on given ID"
  (fluid-test *synth* :id id))

;;--------------------------------------------------

(defun fload (path)
  "Load given .sf2 soundfont"
  (declare (type string path))
  (assert (probe-file path))
  (assert (string= "sf2" (last-elt (cl-ppcre:split #\. path))))
  (fluidsynth:sfload *synth* path 1)
  (fstart))

;;--------------------------------------------------
