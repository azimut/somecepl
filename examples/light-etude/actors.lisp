(in-package :shiny)

(defvar *actors* nil)

(defun update-all-the-things (l)
  (declare (list l))
  (loop :for actor :in l :do
     (update actor)))

(defun model->world (actor)
  (with-slots (pos rot) actor
      (m4:* (m4:translation pos)
            (q:to-mat4 rot))))

(defun delete-actor-name (actor-name)
  (declare (keyword actor-name))
  (setf *actors*
        (delete-if
         (lambda (x) (eq actor-name (slot-value x 'name)))
         *actors*))
  NIL)
(defun delete-actor-class (class-name)
  (declare (string class-name))
  (setf *actors*
        (delete-if
         (lambda (x) (string= class-name (class-name (class-of x))))
         *actors*))
  NIL)

(defmethod sync (x) (+ .5 (* .5 (sin x))))
(defmethod cync (x) (+ .5 (* .5 (cos x))))

(defclass actor ()
  ((name  :initarg :name  :initform (gensym))
   (pos   :initarg :pos   :initform (v! 0 0 0) :accessor pos)
   (rot   :initarg :rot   :initform (v! 0 0 0) :accessor rot)
   (buf   :initarg :buf   :initform (box))
   (scale :initarg :scale :initform 1f0)))

(defclass assimp-thing (actor) ())
(defclass assimp-thing-with-maps (actor)
  ((albedo
    :initform (get-tex "static/32.Rock01-1k/rock01_albedo.jpg"))
   (normal
    :initform (get-tex "static/32.Rock01-1k/rock01_normal.jpg"))
   (height
    :initform (get-tex "static/32.Rock01-1k/rock01_height.jpg"))))
(defclass assimp-bloom (actor) ())

(defclass celestial-sphere (actor)
  ((buf :initform (box 5 5 5))))
(defclass piso (actor)
  ((buf :initform (box 15 .1 15))))
(defclass box (actor)
  ((buf :initform (box 2 2 2))))
(defclass sphere (actor)
  ((buf :initform (sphere 1))))
(defclass cement (actor)
  ((buf :initform (box 1 1 1 t))
   (albedo
    :initform (get-tex "static/16.Plasterwall02-1k/plasterwall02_albedo.jpg"))
   (normal
    :initform (get-tex "static/16.Plasterwall02-1k/plasterwall02_normal.jpg"))
   (height
    :initform (get-tex "static/16.Plasterwall02-1k/plasterwall02_height.jpg"))))

(defun make-celestial-sphere ()
  (let ((obj (make-instance 'celestial-sphere)))
    (push obj *actors*)
    obj))
(defun make-box ()
  (let ((obj (make-instance 'box)))
    (push obj *actors*)
    obj))
(defun make-cement ()
  (let ((obj (make-instance 'cement :pos (v! 0 -1 0))))
    (push obj *actors*)
    obj))
(defun make-sphere ()
  (let ((obj (make-instance 'sphere)))
    (push obj *actors*)
    obj))
(defun make-piso ()
  (let ((obj (make-instance 'piso)))
    (push obj *actors*)
    obj))

(defgeneric update (actor))
(defmethod update (actor))
(defmethod update ((actor box))
  (setf (pos actor) (v! 0 -1 0))
  (setf (rot actor) (q:identity))
  ;; (setf (slot-value actor 'scale) .5)
  ;; (setf (rot actor)
  ;;       (q:from-axis-angle
  ;;        (v! 1 1 1)
  ;;        (radians (* 360 (sync (* .2 (mynow)))))))
  )


(defmethod update ((actor assimp-thing))
  (setf (pos actor) (v! 0 0 0)))
(defmethod update ((actor assimp-thing-with-maps))
  (setf (pos actor) (v! 0 0 0)))
(defmethod update ((actor cement))
;;  (setf (pos actor) (v! 0 -.4 0))
  )
(defmethod update ((actor assimp-bloom))
  (setf (pos actor) (v! 0 0 0)))
