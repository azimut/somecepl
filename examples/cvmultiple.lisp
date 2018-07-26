(in-package :somecepl)

(defun render
    (frame1 frame2 mat)
  (let* ((base 100))
    (if (= (cv:wait-key 30) 27)
        'done
        (cv:with-ipl-images
            ((small (cv:size base base) cv:+ipl-depth-8u+ 3)
             (big   (cv:size (* 3 base) (* 3 base)) cv:+ipl-depth-8u+ 3)
             (big2  (cv:size (* 3 base) (* 3 base)) cv:+ipl-depth-8u+ 3)
             (big3  (cv:size (* 3 base) (* 3 base)) cv:+ipl-depth-8u+ 3)
             )
          ;; grid
          (cv:resize frame1 small)
          (cv:repeat small big)
          ;; center
          (2d-rotate mat 200 200 0f0 .4f0)
          (cv:resize frame2 big2)
          (cv:warp-affine big2 big2 mat)
          (cv:add big big2 big3)
          (cv:show-image "multi" big3)))))

(defun show-videos ()
  "Show the video in FILENAME in a window."
  (cv:with-named-window ("multi" (+ +window-freeratio+
                                    +window-gui-normal+))
    (with-captured-files
        ((capture1 "/home/sendai/testfield/spacecop.mp4")
         (capture2 "/home/sendai/testfield/spacecop.mp4"))
      (let ((mat (cv:create-mat 2 3 5)))
        (skip-to capture2 30)
        (loop
           (update-swank)
           (block continue
             (let ((frame1 (cv:query-frame capture1))
                   (frame2 (cv:query-frame capture2)))
               
               (if (cffi:null-pointer-p frame1)
                   (progn
                     (skip-to capture1 0)
                     (return-from continue)))

               (if (cffi:null-pointer-p frame2)
                   (progn
                     (skip-to capture2 30)
                     (return-from continue)))
             
               (when (eq 'done (render frame1 frame2 mat))
                 (return))
               ;; repeat video ad-infinitum
               )))))))