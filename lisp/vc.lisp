;;; version-control specific protocol implementations

(in-package :autobench)

(defgeneric has-next-directory-p (impl directory)
  (:documentation "Returns whether a NEXT-DIRECTORY call would find a new directory at the time HAS-NEXT-DIRECTORY-P was called."))

(defclass git-vc-mixin () ())

(defmethod next-directory ((impl git-vc-mixin) directory)
  (let ((impl-name (impl-name impl)))
    (with-current-directory directory
      (invoke-logged-program (format nil "git-fetch-~A"
                                     impl-name)
                             *git-binary* `("fetch"))
      (with-input-from-program (missing *git-binary*
                                        "rev-list" "origin" "^HEAD")
        (let* ((next-rev (iterate (for line in-stream missing using #'read-line)
                                  (for last-line previous line)
                                  (finally (return last-line)))))
          (when next-rev
            (directory-for-version impl directory next-rev)))))))

(defmethod directory-for-version ((impl git-vc-mixin) directory version-spec)
  "Return the source directory of IMPL from DIRECTORY for the
  version in VERSION-SPEC.

VERSION-SPEC must contain a git tag or commit id."
  (with-current-directory directory
    (invoke-logged-program (format nil "git-update-~A" (impl-name impl))
                           *git-binary* `("reset" "--hard" ,version-spec)))
  directory)

(defmethod has-next-directory-p ((impl git-vc-mixin) directory)
  
  (let ((impl-name (class-name (class-of impl))))
    (with-current-directory directory
      (invoke-logged-program (format nil "git-fetch-~A" impl-name)
                             *git-binary* `("fetch"))
      (with-input-from-program (missing *git-binary*
                                        "rev-list" "origin" "^HEAD")
        (not (null (read-line missing nil nil)))))))

(defmethod implementation-release-date ((impl git-vc-mixin) directory)
  (with-current-directory directory
    (with-input-from-program (log *git-binary* "log" "--max-count=1")
      (let ((date-line
             (iterate (for line in-stream log using #'read-line)
                      (finding line such-that (and (= (mismatch line "Date:") 5))))))
        (net.telent.date:parse-time
         date-line
         :start 6
         :end (position #\+ date-line :from-end t))))))

(defmethod implementation-version-code ((impl git-vc-mixin) directory)
  (with-current-directory directory
    (with-input-from-program (log *git-binary* "log" "--max-count=1" "--pretty=format:%H")
      (read-line log))))

(defmethod version-from-directory ((impl git-vc-mixin) directory)
  "Returns the output of 'git describe' for the current changeset in DIRECTORY."
  (declare (ignore impl))
  (with-current-directory directory
    (with-input-from-program (description *git-binary* "describe")
      (read-line description))))