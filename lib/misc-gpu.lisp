(in-package :shiny)

(defun-g point-light-apply ((color :vec3)
                            (light-color :vec3)
                            (light-pos :vec3)
                            (frag-pos :vec3)
                            (normal :vec3)
                            (constant :float)
                            (linear :float)
                            (quadratic :float))
  (let* ((light-dir (normalize (- light-pos frag-pos)))
         (diff (saturate (dot normal light-dir)))
         (distance (length (- light-pos frag-pos)))
         (attenuation (/ 1 (+ constant
                              (* linear distance)
                              (* quadratic distance distance))))
         (ambient (* .1 color))
         (diffuse (* diff color))
         )
    (+ ambient diffuse)))

(defun-g dir-light-apply ((color :vec3)
                          (light-color :vec3)
                          (light-pos :vec3)
                          (frag-pos :vec3)
                          (normal :vec3))
  (let* ((light-dir (normalize (- light-pos frag-pos)))
         ;; Diffuse shading
         (diff (saturate (dot normal light-dir)))
         ;; combine
         (ambient (* light-color .1 color))
         (diffuse (* light-color diff color)))
    (+ ambient diffuse)))

;;--------------------------------------------------
;; https://learnopengl.com/Advanced-Lighting/Normal-Mapping
;; "Pushing pixels" code
(defun-g norm-from-map ((normal-map :sampler-2d)
                        (uv :vec2))
  (let* ((norm-from-map
          (s~ (texture normal-map uv) :xyz))
         (norm-from-map
          (normalize (- (* norm-from-map 2.0) 1.0))))
    (v! (x norm-from-map)
        (- 1 (y norm-from-map))
        (z norm-from-map))))

;;--------------------------------------------------
;; https://learnopengl.com/Advanced-Lighting/Parallax-Mapping
;; vec3 viewDir   = normalize(fs_in.TangentViewPos - fs_in.TangentFragPos);
(defun-g parallax-mapping ((uv :vec2)
                           (view-dir :vec3)
                           (depth-map :sampler-2d)
                           (height-scale :float))
  (let* ((height (x (texture depth-map uv)))
         (p      (* (/ (s~ view-dir :xy) (z view-dir))
                    (* height height-scale))))
    (- uv p)))

;;--------------------------------------------------
;; https://catlikecoding.com/unity/tutorials/rendering/part-14/
;; These ones return a "fog-factor" number based on the DISTANCE

(defun-g fog-linear ((frag-pos :vec3)
                     (cam-pos :vec3)
                     (start :float)
                     (end :float))
  (let* ((view-distance (length (- frag-pos cam-pos)))
         (fog-factor
          (+ (* view-distance (/ -1 (- end start)))
             (/ end (- end start)))))
    fog-factor))

(defun-g fog-exp ((frag-pos :vec3)
                  (cam-pos :vec3)
                  (density :float))
  (let ((view-distance (length (- frag-pos cam-pos))))
    (exp2 (- (* view-distance (/ density (log 2)))))))

(defun-g fog-exp2 ((frag-pos :vec3)
                   (cam-pos :vec3)
                   (density :float))
  (let* ((view-distance (length (- frag-pos cam-pos)))
         (fog-density
          (* (/ density (sqrt (log 2))) view-distance))
         (fog-factor
          (exp2 (- (* fog-density fog-density)))))
    fog-factor))

;;--------------------------------------------------
;; Versions that apply the fog and returns the final color

(defun-g fog-linear-apply ((color :vec3)
                           (fog-color :vec3)
                           (frag-pos :vec3)
                           (cam-pos :vec3)
                           (start :float)
                           (end :float))
  (let* ((view-distance (length (- cam-pos frag-pos)))
         (fog-factor
          (+ (* view-distance (/ -1 (- end start)))
             (/ end (- end start)))))
    (mix fog-color color (saturate fog-factor))))

(defun-g fog-exp-apply ((color :vec3)
                        (fog-color :vec3)
                        (frag-pos :vec3)
                        (cam-pos :vec3)
                        (density :float))
  (let* ((view-distance (length (- frag-pos cam-pos)))
        (fog-factor
         (exp2 (- (* view-distance (/ density (log 2)))))))
    (mix fog-color color (saturate fog-factor))))

(defun-g fog-exp2-apply ((color :vec3)
                         (fog-color :vec3)
                         (frag-pos :vec3)
                         (cam-pos :vec3)
                         (density :float))
  (let* ((view-distance (length (- frag-pos cam-pos)))
         (fog-density
          (* (/ density (sqrt (log 2))) view-distance))
         (fog-factor
          (exp2 (- (* fog-density fog-density)))))
    (mix fog-color color (saturate fog-factor))))

;;--------------------------------------------------
;; http://iquilezles.org/www/articles/fog/fog.htm

;; "For example, the color of the fog can tell us about the strengh of the
;; sun. Even more, if we make the color of the fog not constant but
;; orientation dependant we can introduce an extra level of realism to
;; the image. For example, we can change the typical bluish fog color to
;; something yellowish when the view vector aligns with the sun
;; direction. This gives a very natural light dispersion effect. One
;; would argue that sucha an effect shouldn't be called fog but
;; scattering, and I agree, but in the end of the day one simply has to
;; modify a bit the fog equation to get the effect done."

(defun-g apply-fog ((color :vec3)
                    (density :float)
                    (distance :float) ;; camera to point distance
                    (ray-dir :vec3)   ;; camera to point vector
                    (sun-dir :vec3))  ;; sun light direction
  (let* ((fog-amount (- 1 (exp (* (- distance) density))))
         (sun-amount (max (dot ray-dir sun-dir) 0))
         (fog-color  (mix (v! .5 .6 .7) ;; blueish
                          (v!  1 .9 .7) ;; yellowish
                          (pow sun-amount 8))))
    (mix color fog-color fog-amount)))

;; Modified version, with more generic args (works?)
(defun-g apply-fog ((color :vec3)
                    (density :float)
                    (frag-pos :vec3)
                    (cam-pos :vec3)
                    (sun-pos :vec3))
  (let* ((distance (length (- cam-pos frag-pos)))
         (ray-dir  (normalize (- cam-pos frag-pos)))
         (sun-dir  (normalize (- sun-pos frag-pos)))
         (fog-amount (- 1 (exp (* (- distance) density))))
         (sun-amount (max (dot ray-dir sun-dir) 0))
         (fog-color  (mix (v! .5 .6 .7) ;; blueish
                          (v!  1 .9 .7) ;; yellowish
                          (pow sun-amount 8))))
    (mix color fog-color fog-amount)))

;; Height fog - IQ
(defun-g apply-fog ((color :vec3)
                    (fog-color :vec3)
                    (distance :float)
                    (cam-pos :vec3)
                    (frag-pos :vec3))
  (let* ((a .03) ;; .06 - .002
         (b .3) ;; .3   - .02
         (cam-dir (normalize (- frag-pos cam-pos)))
         (fog-amount (/ (* (/ a b)
                           (exp (* (- (y cam-pos)) b))
                           (- 1 (exp (* (- distance)
                                        (y cam-dir)
                                        b))))
                        (y cam-dir))))
    (mix color fog-color (saturate fog-amount))))

;;--------------------------------------------------
;; http://michael-david-palmer.com/fisa/UDK-2010-07/Engine/Shaders/HeightFogCommon.usf
;; https://docs.unrealengine.com/en-us/Engine/Actors/FogEffects/HeightFog
;; Calculates fogging from exponential height fog,
;; returns fog color in rgb, fog factor in a.
;; Fog Height Falloff: Height density factor, controls how the density
;;   increases as height decreases. Smaller values make the
;;   transition larger.
;; x - FogDensity *
;;     exp2(-FogHeightFalloff *
;;          (CameraWorldPosition.z - FogHeight))
;; y - FogHeightFalloff
;; z - CosTerminatorAngle
(defun-g get-exponential-height-fog ((frag-pos :vec3)
                                     (cam-pos :vec3)
                                     (fog-params :vec3)
                                     (light-pos :vec3))
  (let* ((cam-to-receiver (- frag-pos cam-pos))
         (line-integral (* (x fog-params) (length cam-to-receiver)))
         (line-integral
          (if (> (abs (z cam-to-receiver)) .0001)
              (* line-integral (/ (- 1 (exp2 (* (- (y fog-params)) (z cam-to-receiver))))
                                  (* (y fog-params) (z cam-to-receiver))))
              line-integral))
	 ;; 1 in the direction of the light vector, -1 in the opposite direction         
         (cos-light-angle (dot (normalize (- light-pos frag-pos))
                               (normalize cam-to-receiver)))
         (fog-color
          (if (< cos-light-angle (z fog-params))
              (mix (v! .5 .6 .7)
                   (* .5 (+ (v! .5 .6 .7) (v! .1 .1 .1)))
                   (vec3 (saturate (/ (1+ cos-light-angle)
                                      (1+ (z fog-params))))))
              (let ((alpha (saturate (/ (- cos-light-angle (z fog-params))
                                        (- 1 (z fog-params))))))
                (mix (* .5 (+ (v! .5 .6 .7) (v! .1 .1 .1)))
                     (v! .1 .1 .1)
                     (vec3 (* alpha alpha))))))
         (fog-factor (saturate (exp2 (- line-integral)))))
    (v! (* fog-color (- 1 fog-factor)) fog-factor)))

;;--------------------------------------------------
;; PBR - BRDF
;; https://learnopengl.com/PBR/Lighting
(defun-g fresnel-schlick ((cos-theta :float)
                          (f0 :vec3))
  (+ f0
     (* (- 1 f0)
        (pow (- 1 cos-theta) 5))))
(defun-g distribution-ggx ((n :vec3)
                           (h :vec3)
                           (roughness :float))
  (let* ((a  (* roughness roughness))
         (a2 (* a a))
         (n-dot-h (max (dot n h) 0))
         (n-dot-h2 (* n-dot-h n-dot-h))
         (num a2)
         (denom (+ 1 (* n-dot-h2 (- a2 1))))
         (denom (* 3.141516 denom denom)))
    (/ num denom)))
(defun-g geometry-schlick-ggx ((n-dot-v :float)
                               (roughness :float))
  (let* ((r (+ 1 roughness))
         (k (/ (* r r) 8))
         (num n-dot-v)
         (denom (+ (* n-dot-v (- 1 k))
                   k)))
    (/ num denom)))
(defun-g geometry-smith ((n :vec3)
                         (v :vec3)
                         (l :vec3)
                         (roughness :float))
  (let* ((n-dot-v (max (dot n v) 0))
         (n-dot-l (max (dot n l) 0))
         (ggx2 (geometry-schlick-ggx n-dot-v roughness))
         (ggx1 (geometry-schlick-ggx n-dot-l roughness)))
    (* ggx1 ggx2)))
;;--------------------------------------------------
(defun-g billboard-geom (&uniform (camera-pos :vec3)
                                  (view-clip :mat4))
  (declare (output-primitive :kind :triangle-strip :max-vertices 4))
  (let* ((p (s~ (gl-position (aref gl-in 0)) :xyz))
         (to-camera (normalize (- camera-pos p)))
         (up (v! 0 1 0))
         (right (cross to-camera up)))
    ;;
    (decf p (* .5 right))
    (emit ()
          (* view-clip (v! p 1))
          (v! 0 0))
    ;;
    (incf (y p) 1f0)
    (emit ()
          (* view-clip (v! p 1))
          (v! 0 1))
    ;;
    (decf (y p) 1f0)
    (incf p right)
    (emit ()
          (* view-clip (v! p 1))
          (v! 1 0))
    ;;
    (incf (y p) 1f0)
    (emit ()
          (* view-clip (v! p 1))
          (v! 1 1))
    (end-primitive)
    (values)))

;;--------------------------------------------------
;; glsl-atmosphere
;; https://github.com/wwwtyro/glsl-atmosphere/

;; RSI
;; ray-sphere intersection that assumes
;; the sphere is centered at the origin.
;; No intersection when result.x > result.y
(defun-g rsi ((r0 :vec3)
              (rd :vec3)
              (sr :float))
  (let* ((a (dot rd rd))
         (b (* 2 (dot rd r0)))
         (c (- (dot r0 r0) (* sr sr)))
         (d (- (* b b) (* 4 a c))))
    (if (< d 0)
        (v! 100000 -100000)
        (v! (/ (- (- b) (sqrt d))
               (* 2 a))
            (/ (+ (- b) (sqrt d))
               (* 2 a))))))


;; vec3 r normalized ray direction, typically a ray cast from the observers eye through a pixel
;; vec3 r0 ray origin in meters, typically the position of the viewer's eye
;; vec3 pSun the position of the sun
;; float iSun intensity of the sun
;; float rPlanet radius of the planet in meters
;; float rAtoms radius of the atmosphere in meters
;; vec3 kRlh Rayleigh scattering coefficient
;; vec3 kMie Mie scattering coefficient
;; float shRlh Rayleigh scale height in meters
;; float shMie Mie scale height in meters
;; float g Mie preferred scattering direction
(defun-g atmosphere ((r :vec3)
                     (r0 :vec3)
                     (p-sun :vec3)
                     (i-sun :float)
                     (r-planet :float)
                     (r-atmos :float)
                     (k-rlh :vec3)
                     (k-mie :float)
                     (sh-rlh :float)
                     (sh-mie :float)
                     (g :float))
  (let* ((i-steps 16)
         (j-steps 8)
         (pi 3.141592)
         ;; Normalize the sun and view directions
         (p-sun (normalize p-sun))
         (r (normalize r))
         ;; Calculate the step size of the
         ;; primary ray.
         (p (rsi r0 r r-atmos)))
    (if (> (x p) (y p))
        (vec3 0f0)
        (let* ((p (v! (x p)
                      (min (y p) (x (rsi r0 r r-planet)))))
               (i-step-size (/ (- (y p) (x p))
                               i-steps))
               ;; Initialize the primary ray time.
               (i-time 0f0)
               ;; Initialize accumulators for
               ;; Rayleigh and Mie scattering
               (total-rlh (vec3 0f0))
               (total-mie (vec3 0f0))
               ;; Initialize optical depth accum
               ;; for the primary ray.
               (i-od-rlh 0f0)
               (i-od-mie 0f0)
               ;; Calculate the Rayleigh
               ;; and Mie phases
               (mu (dot r p-sun))
               (mumu (* mu mu))
               (gg (* g g))
               (p-rlh (* (/ 3 (* 16 pi))
                         (+ 1 mumu)))
               (p-mie (/ (* (/ 3 (* 8 pi))
                            (* (- 1 gg) (+ 1 mumu)))
                         (* (pow (- (+ 1 gg) (* 2 mu g))
                                 1.5)
                            (* 2 gg))))
               (i 0))
          ;; sample the primary key
          (dotimes (i i-steps)
            (let* (;; Calculate the primary ray sample position
                   (i-pos (+ r0 (* r (+ i-time (* i-step-size .5)))))
                   ;; Calculate the height of the sample
                   (i-height (- (length i-pos) r-planet))
                   ;; Calculate the optical depth of the Rayleigh
                   ;; and Mie scattering for this step.
                   (od-step-rlh (* i-step-size (exp (/ (- i-height) sh-rlh))))
                   (od-step-mie (* i-step-size (exp (/ (- i-height) sh-mie)))))
              ;; Accumulate optical depth.
              (incf i-od-rlh od-step-rlh)
              (incf i-od-mie od-step-mie)
              (let (;; Calculate the step size of the secondary ray
                    (j-step-size (/ (y (rsi i-pos p-sun r-atmos)) j-steps))
                    ;; Initialize the secondary ray time
                    (j-time 0f0)
                    ;; Initialize optical depth accumulators for the sec ray
                    (j-od-rlh 0f0)
                    (j-od-mie 0f0))
                ;; Sample the seconday ray
                (dotimes (j j-steps)
                  (let* (;; Calculate the secondary ray sample position
                         (j-pos (+ i-pos (* p-sun (+ j-time (* j-step-size .5)))))
                         ;; Calculate the height of the sample
                         (j-height (- (length j-pos) r-planet)))
                    ;; Accumulate the optical depth
                    (incf j-od-rlh (* j-step-size (exp (/ (- j-height) sh-rlh))))
                    (incf j-od-mie (* j-step-size (exp (/ (- j-height) sh-mie))))
                    ;; Increment the secondary ray time
                    (incf j-time j-step-size)))
                ;; Calculate attenuation
                (let ((attn (exp (- (+ (* k-mie (+ i-od-mie j-od-mie))
                                       (* k-rlh (+ i-od-rlh j-od-rlh)))))))
                  ;; Accumulate scattering
                  (incf total-rlh (* od-step-rlh attn))
                  (incf total-mie (* od-step-mie attn))
                  ;; Increment the primary ray time
                  (incf i-time i-step-size)))))
          ;; Calculate and return the final color
          (* i-sun (+ (* p-rlh k-rlh total-rlh)
                      (* p-mie k-mie total-mie)))))))


;;--------------------------------------------------
;; WORKS???
;; http://www.voidcn.com/article/p-nvhpdsyj-yy.html
(defun-g linear-eye-depth ((d :float))
  (let* ((n .1)
         (f 400f0)
         (zz (/ (/ (- 1 (/ f n)) 2) f))
         (zw (/ (/ (+ 1 (/ f n)) 2) f)))
    (/ 1 (+ (* zz d) zw))))

;; https://learnopengl.com/Advanced-OpenGL/Depth-testing
;; Because the linearized depth values range from near to far most of
;; its values will be above 1.0 and displayed as completely white. By
;; dividing the linear depth value by far in the main function we
;; convert the linear depth value to roughly the range [0, 1]. This
;; way we can gradually see the scene become brighter the closer the
;; fragments are to the projection frustum's far plane, which is
;; better suited for demonstration purposes.
(defun-g linearize-depth ((depth :float))
  (let* ((near 0.1)
         (far 400f0)
         (z (- (* depth 2.0) 1.0)))
    (/ (* 2.0 (* near far))
       (- (+ far near) (* z (- far near))))))

;; Three.js - packaging.glsl.js
(defun-g view-zto-orthographic-depth ((view-z :float)
                                      (near :float)
                                      (far :float))
  (/ (+ view-z near)
     (- near far)))

(defun-g perspective-depth-to-view-z ((inv-clip-z :float)
                                       (near :float)
                                       (far :float))
  (/ (* near far)
     (- (* (- far near) inv-clip-z) far)))

(defun-g read-depth ((depth-sampler :sampler-2d)
                     (coord :vec2)
                     (camera-near :float)
                     (camera-far :float))
  (let* ((frag-coord-z (x (texture depth-sampler coord)))
         (view-z (perspective-depth-to-view-z frag-coord-z
                                              camera-near
                                              camera-far)))
    (view-zto-orthographic-depth view-z camera-near camera-far)))

;;--------------------------------------------------
(defun-g z-texture ((sam :sampler-2d)
                    (uv :vec2))
  (- 1 (/ (linear-eye-depth (x (texture sam uv)))
          400f0)))

(defun-g z-texture ((sam :sampler-2d)
                    (uv :vec2))
  (- 1 (read-depth sam uv .1 400f0)))

(defun-g z-texture ((sam :sampler-2d)
                    (uv :vec2))
  (- 1 (x (texture sam uv))))

(defun-g god-rays-frag ((uv :vec2)
                        &uniform
                        (t-input :sampler-2d)
                        (sun-position :vec2)
                        (pass :float))
  (let* (;; Screen space
         (uv uv)
         (f-step-size (pow 6 (- pass)))
         (delta (- sun-position uv))
         (dist (length delta))
         (stepv (/ (* f-step-size delta) dist))
         (iters (/ dist f-step-size))
         (col 0f0))
    (dotimes (i 5)  
      (incf col (if (and (<= i iters)
                         (< (y uv) 1))
                    (z-texture t-input uv)
                    0f0))
      (incf uv stepv))
    ;; (when (and (<= 0 iters) (< (y uv) 1))
    ;;   (incf col (z-texture t-input uv))
    ;;   (incf uv stepv))
    ;; (when (and (<= 1 iters) (< (y uv) 1))
    ;;   (incf col (z-texture t-input uv))
    ;;   (incf uv stepv))
    ;; (when (and (<= 2 iters) (< (y uv) 1))
    ;;   (incf col (z-texture t-input uv))
    ;;   (incf uv stepv))
    ;; (when (and (<= 3 iters) (< (y uv) 1))
    ;;   (incf col (z-texture t-input uv))
    ;;   (incf uv stepv))
    ;; (when (and (<= 4 iters) (< (y uv) 1))
    ;;   (incf col (z-texture t-input uv))
    ;;   (incf uv stepv))
    ;; (when (and (<= 5 iters) (< (y uv) 1))
    ;;   (incf col (z-texture t-input uv)))
    ;; (vec3 (- 1 (/ (linear-eye-depth (x (texture t-input uv)))
    ;;               400f0)))
    ;;(vec3 (- 1 (read-depth t-input uv .1 400f0)))
    (v! (vec3 (/ col 6)) 1)
    ;;(v! (vec3 (x (texture t-input uv))) 1)
    ))

