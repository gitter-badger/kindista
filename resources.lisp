(in-package :kindista)

;bug list
;fix top tag display
 
(defun resources-help-text ()
  (welcome-bar
    (html
      (:h2 "Getting started with resources")
      (:p "Here are some things you can do to get started:")
      (:ul
        (:li (:a :href "/resources/new" "Post a resource") " you have that someone else in the community might be able to use.")
        (:li "Browse recently posted resources listed below.")
        (:li "Find specific resources by selecting keywords from the " (:strong "browse by keyword") " menu.")
        (:li "Search for resources using the search "
          (:span :class "menu-button" "button")
          (:span :class "menu-showing" "bar")
          " at the top of the screen.")))))

(defroute "/resources/new" ()
  (:get
    (require-user
      (enter-inventory-text :title "Post a resource"
                            :action "/resources/new"
                            :selected "resources")))
  (:post
    (post-new-inventory-item "resource" :url "/resources/new")))

(defroute "/resources/<int:id>" (id)
  (:get
    (setf id (parse-integer id))
    (aif (db id)
      (with-user
        (standard-page
          "First few words... | Kindista"
          (html
            (:div :class "activity"
              (str (inventory-activity-item "resource" (gethash id *db-results*) :show-distance t))))
          :selected "resources"))
      (standard-page "Not found" "not found")))
  (:post
    (require-user
      (setf id (parse-integer id)) 
      (aif (db id)
        (cond
          ((and (post-parameter "love")
                (member (getf it :type) '(:gratitude :resource :resource)))
           (love id)
           (see-other (or (post-parameter "next") (referer))))
          ((and (post-parameter "unlove")
                (member (getf it :type) '(:gratitude :resource :resource)))
           (unlove id)
           (see-other (or (post-parameter "next") (referer)))))
        (standard-page "Not found" "not found")))))

(defroute "/resources/<int:id>/edit" (id)
  (:get
    (require-user
      (let* ((resource (db (parse-integer id))))
        (require-test ((eql *userid* (getf resource :by))
                     "You can only edit resources you have posted.")
          (enter-inventory-tags :title "Edit your resource"
                                :action (s+ "/resources/" id "/edit")
                                :text (getf resource :text)
                                :tags (getf resource :tags)
                                :button-text "Save resource"
                                :selected "resources")))))
  (:post
    (post-existing-inventory-item "resource" :id id
                                            :url (s+ "/resources/" id "/edit"))))

(defroute "/resources" ()
  (:get
    (with-user
      (with-location
        (let* ((page (if (scan +number-scanner+ (get-parameter "p"))
                       (parse-integer (get-parameter "p"))
                       0))
               (q (get-parameter "q"))
               (base (iter (for tag in (split " " (get-parameter "kw")))
                           (when (scan *tag-scanner* tag)
                             (collect tag))))
               (start (* page 20)))
          (when (string= q "") (setf q nil))
          (multiple-value-bind (tags items)
              (nearby-inventory-top-tags :resource :base base :q q)
            (standard-page
             "resources"
             (inventory-body-html "resource" :base base 
                                             :q q 
                                             :items items 
                                             :start start 
                                             :page page)
            :top (when (getf *user* :help)
                   (resources-help-text))
            :search q
            :search-scope (if q "resources" "all")
            :right (browse-inventory-tags "resource" :q q :base base :tags tags)
            :selected "resources")))))))


(defroute "/resources/all" ()
(:get
  (require-user
    (let ((base (iter (for tag in (split " " (get-parameter "kw")))
                      (when (scan *tag-scanner* tag)
                        (collect tag)))))
      (multiple-value-bind (tags items)
          (nearby-inventory-top-tags *resource-geo-index* :count 10000 :subtag-count 10)
        (standard-page
         "resources"
           (browse-all-inventory-tags "resource" :base base :tags tags)
           :top (when (getf *user* :help)
                 (resources-help-text))
           :selected "resources"))))))
