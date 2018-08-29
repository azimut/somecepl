(in-package :somecepl)

(defvar *light-factor* 1f0)

(defgeneric draw (actor camera))
(defmethod draw (actor camera))

(defmethod draw ((actor ground) camera)
  (with-slots (buf) actor
    (map-g #'ground-pipe buf
           :time (mynow)
           :cam-pos (pos camera)
           :light-factor *light-factor*
           :model-world (model->world actor)
           :world-view (world->view camera)
           :view-clip  (projection camera))))

(defmethod draw ((actor lead) camera)
  (with-slots (buf) actor
    (map-g #'lead buf
           :time (mynow)
           :light-factor *light-factor*
           :model-world (model->world actor)
           :world-view (world->view camera)
           :view-clip  (projection camera))))

(defmethod draw ((actor voz) camera)
  (with-slots (buf) actor
    (with-instances 10
      (map-g #'pipe buf
             :time (mynow)
             :lead-pos (pos *lead*)
             :light-factor *light-factor*
             :model-world (model->world actor)
             :world-view (world->view camera)
             :view-clip  (projection camera)))))

(defmethod draw ((actor sphere) camera)
  (with-setf:with-setf (cull-face) :front
    (with-slots (buf) actor
      (map-g #'white buf
             :time (mynow)
             :light-factor *light-factor*
             :model-world (model->world actor)
             :world-view (world->view camera)
             :view-clip  (projection camera)))))

(defmethod draw ((actor wall) camera)
  (with-slots (buf) actor
    (map-g #'white buf
           :time (mynow)
           :model-world (model->world actor)
           :world-view (world->view camera)
           :view-clip  (projection camera))))

;;----------------------------------------

(defun render-all-the-things (actor camera)
  (update actor)
  (draw actor camera))