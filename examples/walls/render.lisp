(in-package :somecepl)

(defun-g g-rand ((x :float))
  (fract (* (sin x)
            10000f0)))

(defun-g cyn ((x :float))
  (+ .5 (* .5 (cos x))))

(defun-g syn ((x :float))
  (+ .5 (* .5 (sin x))))

(defun-g circle-g ((uv :vec2) (size :float))
  (v3! (* size
          (distance (v! .5 .5)
                    uv))))

;;--------------------------------------------------

;; (defun-g frag
;;     ((uv :vec2) (frag-norm :vec3) (frag-pos :vec3) &uniform
;;      (time :float) (rms :float))
;;   (let* ((vec-to-light (- (v! 0 0 -20)
;;                           frag-pos))
;;          (dir-to-light (normalize vec-to-light))
;;          (color (v! .2 .2 .2 1))
;;          (color (+ (* (+ 1 (* .2 (syn (* 100 time))))
;;                       (dot dir-to-light frag-norm))
;;                    color)))
;;     color))

(defun-g vert
    ((vert g-pnt) &uniform
     (model-world :mat4) (world-view :mat4) (view-clip :mat4)
     (time :float))
  (let* ((pos       (pos vert))
         (norm      (norm vert))
         (tex       (tex vert))
         (norm      (* (m4:to-mat3 model-world) (norm vert)))
         (world-pos (* model-world (v! pos 1)))
         (view-pos  (* world-view  world-pos))
         (clip-pos  (* view-clip   view-pos)))
    (values clip-pos
            tex
            norm
            (s~ world-pos :xyz))))

;;--------------------------------------------------

(defun-g sphere-frag
    ((uv :vec2) (frag-norm :vec3) (frag-pos :vec3) &uniform
     (time :float) (light-factor :float))
  (let* (
         ;; (vec-to-light (- (v! 0 0 0)
         ;;                    frag-pos))
         ;;         (dir-to-light (normalize vec-to-light))
         (light-color (v! .2 .9 .09)) ;; .9 .1 0 ;; .2 .9 .1
         (light-size (+ (/ 90 light-factor) (* 2 (sin (* 100 time)))))
         (circle (circle-g uv light-size))
         (sky (- 1 (* circle light-color)))
         (noise (+  -3 (perlin-noise (* 40 (+ (v! (* .009 time) 0) uv)))))
         (landmass (* (v! .2 .2 .2) ;; 0 .2 .9 ;; .2 .2 .2
                      (v3! noise)
                      (clamp (v3! (- (y frag-pos))) 0 1.2)))
         (starry (let ((r (g-rand (* 100 (y uv)))))
                   (if (> r .9991)
                       (v3! r)
                       (v3! 0))))
         (starry (clamp (* starry (y frag-pos)) 0 1))
         (final (+ (* .9 landmass)
                   (clamp sky 0 1)
                   (* 2 (+ .2 (* .05 (sin (* 10 time)))) starry)))
;;         (final (+ (* 1 (dot dir-to-light frag-norm)) (s~ final :xyz)))
         )
    final))
;;--------------------------------------------------

(defun-g voz-vert
    ((vert g-pnt) &uniform
     (model-world :mat4) (world-view :mat4) (view-clip :mat4)
     (time :float) (lead-pos :vec3))
  (let* ((pos       (pos vert))
         (time      (+ time gl-instance-id))
         (norm      (norm vert))
         (tex       (tex  vert))
         (norm      (* (m4:to-mat3 model-world) (norm vert)))

         (world-pos (* model-world (v! pos 1)))
         (vec-to-lead   (- lead-pos (s~ world-pos :xyz)))
         (dic-to-lead (normalize vec-to-lead))
         (new-pos (+ lead-pos
                     (v! (* 70  (cos time) (sin time))
                         (* 20  (cos time))
                         (+ -50 (* 20 (cos time))))))
         (world-pos (+ world-pos
                       (v! new-pos 0)))
;;         (world-pos (* world-pos (m3:point-at (v! 1 1 1) new-pos lead-pos)))
         
         (view-pos  (* world-view  world-pos))
         (clip-pos  (* view-clip   view-pos)))
    (values clip-pos
            tex
            norm
            (s~ world-pos :xyz))))

(defun-g voz-frag
    ((uv :vec2) (frag-norm :vec3) (frag-pos :vec3) &uniform
     (time :float) (light-factor :float) (cam-pos :vec3))
  (let* ((light-pos (v! 0 30 -150))
         (obj-color (v! .2 .9 1))
         ;; Ambient
         (light-ambient .15)
         ;; Diffuse
         (vec-to-light  (- light-pos frag-pos))
         (dir-to-light  (normalize vec-to-light))
         (light-diffuse (saturate (dot frag-norm dir-to-light)))


         ;; Specular
         (vec-to-cam (- cam-pos frag-pos))
         (dir-to-cam (normalize vec-to-cam))
         (reflection (normalize (reflect (- dir-to-light)
                                         frag-norm)))
         (spec-foo .11)
         (spec (* spec-foo (pow (saturate
                                 (dot dir-to-cam reflection))
                                32)))
                  
         (lights (* light-factor
                    (+ light-diffuse
                       light-ambient
                       spec)))
         (result (* lights obj-color)))
    (v! result 0)))

;;--------------------------------------------------

(defun-g ground-vert
    ((vert g-pnt) &uniform
     (model-world :mat4) (world-view :mat4) (view-clip :mat4)
     (time :float) (tex-noise :sampler-2d))
  (let* ((pos       (pos vert))
         (norm      (norm vert))
         (tex       (tex vert))
         (dis (* 2
                 (x
                  (texel-fetch
                   tex-noise
                   (ivec2 (v! (int (floor (* 100 (/ (+ 50 (x pos)) 100))))
                              (int (floor (* 100 (/ (+ 50 (z pos)) 100))))))
                   0))))
         (pos (+ pos (v! 0 dis 0)))
         (pos (* pos .1))
         (norm      (* (m4:to-mat3 model-world) (norm vert)))
         (world-pos (* model-world (v! pos 1)))
         (view-pos  (* world-view  world-pos))
         (clip-pos  (* view-clip   view-pos)))
    (values clip-pos
            tex
            norm
            (s~ world-pos :xyz))))

(defun-g ground-frag
    ((uv :vec2) (frag-norm :vec3) (frag-pos :vec3) &uniform
     (time :float))
  (let* ((color (v3! 1)))
    color))


(defun-g pass-vert ((pos :vec2))
  (values (v! pos 0 1)
          (+ .5 (* .5 pos))))
(defun-g pass-frag ((uv :vec2) &uniform (time :float))
  (let ((color (v3! (perlin-noise (+ time (* 10 uv))))))
    (v! color 0)))
(defpipeline-g pass-pipe ()
  (pass-vert :vec2)
  (pass-frag :vec2))

(defpipeline-g ground-pipe ()
  :vertex (ground-vert g-pnt)
  :fragment (voz-frag :vec2 :vec3 :vec3))

;; No verted logic, voz shading
(defpipeline-g lead ()
  :vertex (vert g-pnt)
  :fragment (voz-frag :vec2 :vec3 :vec3))

;; Vertex movement, voz shading
(defpipeline-g pipe ()
  :vertex (voz-vert g-pnt)
  :fragment (voz-frag :vec2 :vec3 :vec3))

;; No vextex logic, sphere shading
(defpipeline-g white ()
  :vertex (vert g-pnt)
  :fragment (sphere-frag :vec2 :vec3 :vec3))
