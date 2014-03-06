;;; Copyright 2012-2013 CommonGoods Network, Inc.
;;;
;;; This file is part of Kindista.
;;;
;;; Kindista is free software: you can redistribute it and/or modify it
;;; under the terms of the GNU Affero General Public License as published
;;; by the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; Kindista is distributed in the hope that it will be useful, but WITHOUT
;;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
;;; License for more details.
;;;
;;; You should have received a copy of the GNU Affero General Public License
;;; along with Kindista.  If not, see <http://www.gnu.org/licenses/>.

(in-package :kindista)

(defun nearby-profiles (index)
  (with-location
    (labels ((distance (result)
               (air-distance *latitude* *longitude* (result-latitude result) (result-longitude result))))
      (mapcar #'result-id
              (sort (remove *userid* (geo-index-query index *latitude* *longitude* 50) :key #'result-id)
                    #'< :key #'distance)))))

(defun nearby-profiles-html (type tabs)
  (let* ((page (if (scan +number-scanner+ (get-parameter "p"))
                (parse-integer (get-parameter "p"))
                0))
         (start (* page 20)))
    (standard-page
      (s+ "Nearby " type)
      (html
        (when (string= type "groups")
          (str (menu-horiz "actions" (html (:a :href "/groups/new" "create a new group")))))
        (str tabs)
        (multiple-value-bind (ids more)
          (sublist (nearby-profiles (if (string= type "people")
                                      *people-geo-index*
                                      *groups-geo-index*))
                   start 20)
          (when (> page 0)
            (str (paginate-links page more)))
          (dolist (id ids)
            (str (if (string= type "people")
                   (person-card id)
                   (group-card id))))
          (str (paginate-links page more))))
      :selected type
      :right (html
               (str (login-sidebar))
               (str (donate-sidebar))
               (str (invite-sidebar))))))

(defun sorted-contacts ( &key (userid *userid*) (contact-type :person))
  (sort
    (remove-if-not #'(lambda (id) (eql (result-type (gethash id *db-results*))
                                       contact-type))
                   (copy-list (db userid :following)))
    #'string-lessp :key #'person-name))

(defun my-contacts (contact-type tabs selected)
  (let ((contacts (sorted-contacts :contact-type contact-type)))
      (standard-page
      "Contacts"
      (html
        (str tabs)
        (unless contacts
          (htm (:h3 "No contacts")))
        (let ((letters ()))
          (dolist (id contacts)
            (let ((char (char-upcase (elt (db id :name) 0))))
              (unless (member char letters)
                (push char letters))))
          (htm
            (:a :name "index")
            (:p (fmt "~{<a href=#~(~:C~)>~:*~:C</a>~^ | ~}" (nreverse letters)))))

        (let ((letter nil))
          (dolist (id contacts)
            (let ((char (char-upcase (elt (db id :name) 0))))
              (unless (eq char letter)
                (htm (:a :name (char-downcase char))
                     (:h3 (str char) (:small " (" (htm (:a :href "#index" " back to index ")) ")")))
                (setf letter char))
              (str (person-card id))))))

      :selected selected
      :right (html
               (str (donate-sidebar))
               (str (invite-sidebar)))))
  )

(defun profile-bio-section-html (title content &key editing editable section-name groupid)
  (when (string= content "")
    (setf content nil))
  (when (or content editing editable)
    (html
      (:div :class "bio-section"
        (:h2 (str title)
             (when (and editable (not editing))
               (htm (:a :href (strcat *base-url* "/about?edit=" section-name)
                        (:img :class "icon" :src "/media/icons/pencil.png")))))
        (cond
          (editing
            (htm
              (:form :method "post" :action "/settings"
                (:input :type "hidden" :name "next" :value (strcat *base-url* "/about"))
                (awhen groupid
                  (htm (:input :type "hidden" :name "groupid" :value it)))
                (:textarea :name (strcat "bio-" section-name)
                           (awhen content (str (escape-for-html it))))
                (:button :class "yes" :type "submit" :name "save" "Save")
                (:a :class "cancel red" :href *base-url* "Cancel"))))
          ((not content)
            (htm
              (:p :class "empty" "I'm empty... fill me out!")))

          (t
            (htm
              (:p (str (html-text content))))))))))

(defun profile-bio-html (id)
  ; is the user editing one of the sections?
  ; should we show edit links for the sections?
  ;  if the user is looking at their own bio
  ;   and they are not currently editing another section
  ;
  (require-user
    (let* ((strid (username-or-id id))
           (editing (cond
                      ((string= (get-parameter "edit") "doing") 'doing)
                      ((string= (get-parameter "edit") "contact") 'contact)
                      ((string= (get-parameter "edit") "into") 'into)
                      ((string= (get-parameter "edit") "summary") 'summary)
                      ((string= (get-parameter "edit") "skills") 'skills)))
           (entity (db id))
           (name (getf entity :name))
           (entity-type (getf entity :type))
           (group-id (when (eql entity-type :group) id))
           (group-adminp (find *userid* (getf entity :admins)))
           (editable (when (not editing)
                       (case entity-type
                         (:person (eql id *userid*))
                         (:group group-adminp))))
           (profile-p (or (getf entity :bio-into)
                          (getf entity :bio-contact)
                          (getf entity :bio-skils)
                          (getf entity :bio-doing)
                          (getf entity :bio-summary)))
           (mutuals (mutual-connections id))
           (mutual-links (html (:ul (dolist (link (alpha-people-links mutuals))
                                      (htm (:li (str link)))))))
           (*base-url* (case entity-type
                         (:person (strcat "/people/" strid))
                         (:group (strcat "/groups/" strid)))))
      (flet ((bio-section (title section)
               (let ((section-name (string-downcase (symbol-name section))))
                 (profile-bio-section-html
                   title
                   (getf entity(make-keyword (string-upcase
                                               (s+ "bio-" section-name))))
                   :groupid group-id
                   :section-name section-name
                   :editing (eql editing section)
                   :editable editable))))
        (pprint group-id)
        (terpri)
        (standard-page
          name
          (html
            (str (profile-tabs-html id :tab :about))
            (if (or (eql id *userid*) profile-p group-adminp)
              (htm
                (:div :class "bio"
                  (str (bio-section (case entity-type
                                      (:person "My self-summary")
                                      (:group (s+ "About " name)))
                                    'summary))
                  (when (eql entity-type :person)
                    (str (bio-section
                           "What I'm doing with my life"
                           'doing)))
                  (str (bio-section
                         (case entity-type
                           (:person "What I'm really good at")
                           (:group "What we're really good at"))
                         'skills))
                  (when (eql entity-type :person)
                    (str (bio-section
                           "I'm also into"
                           'into)))
                  (str (bio-section
                         (case entity-type
                           (:person "You should contact me if")
                           (:group "Contact us if"))
                         'contact))))
              (case entity-type
                (:person (htm (:h3 "This person hasn't written anything here.")))
                (:group (htm (:h3 "This group hasn't written anything here."))))))
          :right (case entity-type
                   (:person (when mutuals
                              (mutual-connections-sidebar mutual-links)))
                   (:group (group-sidebar id)))
          :top (profile-top-html id)
          :selected (if (eql entity-type :group)
                      "groups"
                      "people"))))))

(defun profile-activity-items (&key (id *userid*) (page 0) (count 20) type display members)
  (let ((items (cond
                ((string= display "all")
                 (group-members-activity (cons id members) :type type))
                ((string= display "members")
                 (group-members-activity members :type type))
                ((eql id *userid*)
                 (gethash id *profile-activity-index*))
                (t (remove-private-items
                     (gethash id *profile-activity-index*)))))
        (start (* page count))
        (i 0))

    (html
      (iter
        (let ((item (car items)))
          (when (or (not item)
                    (>= i (+ count start)))
            (finish))

          (when
            (and (or (not type)
                     (if (eql type :gratitude)
                       (or (and (eql :gratitude (result-type item))
                                (not (eql id (first (result-people item)))))
                           (and (eql :gift (result-type item))
                                (not (eql id (car (last (result-people item)))))))
                       (eql type (result-type item))))
                 (> (incf i) start))

            (case (result-type item)
              (:gratitude
                (str (gratitude-activity-item item)))
              (:person
                (str (joined-activity-item item)))
              (:gift
                (str (gift-activity-item item)))
              (:offer
                (str (inventory-activity-item "offer" item
                                          :show-what (unless (eql type :offer) t))))
              (:request
                (str (inventory-activity-item "request" item
                                            :show-what (unless (eql type :request) t)))))))

          (setf items (cdr items))

          (finally
            (str (paginate-links page (cdr items) (s+ (url-compose (script-name*) "display" display)))))))))

(defun profile-top-html (id)
  (let* ((entity (db id))
         (entity-type (getf entity :type))
         (is-contact (member id (getf *user* :following)))
         (pendingp (assoc *userid* (gethash id *group-membership-requests-index*)))
         (memberp (member *userid* (getf entity :members)))
         (adminp (member *userid* (getf entity :admins))))
    (html
      (when pendingp
        (htm 
          (:div :class "err bold"
             "Your request to join this group is awaiting approval by the group's admin(s).")))
      (:div :id "profile-top"
        (when adminp
          (htm (:a :href (url-compose "/settings/public" "groupid" id)
                   :class "small blue float-right"
                   (:img :src "/media/icons/settings.png" :class "small")
                   "group settings")))
        (:img :class "bigavatar" :src (get-avatar-thumbnail id 300 300)) 
        (:div :class "basics"
          (:h1 (str (getf entity :name))
               (cond
                 ((getf entity :banned)
                  (htm (:span :class "help-text" " (deleted account)")))
                 ((eq (getf entity :active) nil)
                  (htm (:span :class "help-text" " (inactive account)")))))

          (awhen (getf entity :category)
            (htm (str it)
                 (:br)))

          (cond
           ((eql (getf entity :location-privacy) :public)
            (htm (:div :class "city"
                  (awhen (getf entity :street)
                    (htm (str it) (:br)))
                  (str (getf entity :city)) ", " (str (getf entity :state)))))
           ((getf entity :city)
            (htm (:p :class "city" (str (getf entity :city)) ", " (str (getf entity :state))))))))

      (unless (or (eql id *userid*) (not *userid*))
        (htm
          (:div :class "profile-buttons"
            (:div :class "float-right"
              (when (and (db id :active)
                         (db *userid* :active)
                         (eql entity-type :person))
                (htm
                  (:form :method "post" :action "/conversations/new"
                    (:input :type "hidden" :name "next" :value (script-name*))
                    (:button :class "yes small" :type "submit" :name "add" :value id "Send a message"))))

                (:form :method "GET"
                       :action (case entity-type
                                 (:person (strcat "/people/" (username-or-id id) "/reputation"))
                                 (:group (strcat "/groups/" (username-or-id id) "/reputation")))
                  (:button :class "yes small" :type "submit" "Express gratitude")) 

              (when (eql entity-type :group)
                (cond
                  (adminp
                   (htm (:form :method "get"
                               :action (strcat "/groups/" (username-or-id id) "/invite-members")
                           (:button :class "yes small" :type "submit"  "+add members"))))
                  (memberp
                   (htm (:form :method "POST" :action (strcat "/groups/" id "/members")
                          (:input :type "hidden" :name "next" :value *base-url*)
                          (:button :class "cancel small" :name "leave-group" :value id :type "submit"
                            (str "Leave group")))))

                  ((and (not pendingp)(not (eql (getf entity :membership-method) :invite-only)))
                   (htm (:form :method "POST" :action (strcat "/groups/" id "/members")
                          (:input :type "hidden" :name "next" :value *base-url*)
                          (:button :class "yes small" :type "submit" :name "request-membership" :value id
                            (str "Join group")))))

                  ((assoc *userid* (gethash id *group-membership-invitations-index*))
                   (htm (:form :method "POST" :action (strcat "/groups/" id "/members")
                          (:input :type "hidden" :name "next" :value *base-url*)
                          (:button :class "yes small" :type "submit" :name "accept-group-membership-invitation" :value id
                          (str "Join group")))))))

              (when *userid*
                (htm
                  (:form :method "POST" :action "/contacts"
                    (:input :type "hidden" :name (if is-contact "remove" "add") :value id)
                    (:input :type "hidden" :name "next" :value *base-url*)
                  (:button :class (if is-contact "cancel small" "yes small") :type "submit" (str (if is-contact "Remove from contacts" "Add to contacts")))))))))))))

(defun simple-profile-top (id)
  (let* ((entity (db id))
         (type (getf entity :type))
         (link (case type
                 (:person (s+ "/people/" (username-or-id id)))
                 (:group (s+ "/groups/" (username-or-id id))))))
    (html
      (:div :class "id-bar"
        (:a :href link (:img :src (get-avatar-thumbnail id 70 70)))
        (:a :href link (str (getf entity :name)))))))

(defun profile-tabs-html (id &key tab)
  (let* ((entity (db id))
         (profile-p (or (getf entity :bio-into)
                        (getf entity :bio-contact)
                        (getf entity :bio-skils)
                        (getf entity :bio-doing)
                        (getf entity :bio-summary)))
         (self (eql id *userid*))
         (admin (member *userid* (getf entity :admins)))
         (active (getf entity :active))
         (show-bio-tab (or profile-p self admin)))
    (html
      (:menu :class "bar"
        (:h3 :class "label" "Profile Menu")
        (when show-bio-tab
          (if (eql tab :about)
            (htm (:li :class "selected" "About"))
            (htm (:li (:a :href (strcat *base-url* "/about") "About")))))

        (if (eql tab :activity)
          (htm (:li :class "selected" "Activity"))
          (htm (:li (:a :href (strcat *base-url* "/activity") "Activity"))))
        (if (eql tab :gratitude)
          (htm (:li :class "selected" "Reputation"))
          (htm (:li (:a :href (strcat *base-url* "/reputation") "Reputation"))))
        (when (eq active t)
          (if (eql tab :offer)
            (htm (:li :class "selected" "Offers"))
            (htm (:li (:a :href (strcat *base-url* "/offers") "Offers"))))
          (if (eql tab :request)
            (htm (:li :class "selected" "Requests"))
            (htm (:li (:a :href (strcat *base-url* "/requests") "Requests")))))

        (when (and (eql (getf entity :type) :person)
                   (mutual-connections id))
          (if (eql tab :connections)
            (htm (:li :class "selected" "Mutual Connections"))
            (htm (:li :class "no-rightbar" (:a :href (strcat *base-url* "/connections") "Mutual Connections")))))

        (when (eql (getf entity :type) :group)
          (if (eql tab :members)
            (htm (:li :class "selected" "Group Members"))
            (htm (:li :class "no-rightbar" (:a :href (strcat *base-url* "/members") "Group Members")))))))))

(defun profile-activity-html (id &key type right)
  (let* ((entity (db id))
         (strid (username-or-id id))
         (entity-type (getf entity :type))
         (name (getf entity :name))
         (display (cond
                    ((or (string= (get-parameter "display") "group")
                         (and (get-parameter "group")
                            (not (get-parameter "members"))))
                     "group")
                    ((or (string= (get-parameter "display") "members")
                         (and (get-parameter "members")
                              (not (get-parameter "group"))))
                     "members")
                    ((eql entity-type :group)
                     "all")))
         (groupid (when (eql entity-type :group) id))
         (members (when groupid (append (getf entity :admins) (getf entity :members))))
         (adminp (when (member *userid* (getf entity :admins)) t))
         (*base-url* (case entity-type
                       (:person (strcat "/people/" strid))
                       (:group (strcat "/groups/" strid)))))
    (standard-page
      name
      (html
        (when *user* (str (profile-tabs-html id :tab (or type :activity))))
        (when (or (eql id *userid*) adminp)
          (when (eql type :request)
            (htm (str (simple-inventory-entry-html "a" "request"
                                                   :groupid (when adminp groupid)))))
          (when (eql type :offer)
            (htm (str (simple-inventory-entry-html "an" "offer"
                                                   :groupid (when adminp groupid))))))
        (when (and (eql type :gratitude)
                   (not (eql id *userid*))
                   (eql (getf entity :active) t))
          (htm
            (:div :class "item"
             (:h4 "Do you have gratitude to share for " (str (getf entity :name)) "?")
             (:form :method "post" :action "/gratitude/new"
               (unless (member *userid* (getf entity :admins))
                 (awhen (groups-with-user-as-admin)
                   (htm
                     (:strong :class "small" "Post gratitude from "))
                     (str (identity-selection-html (or groupid *userid*)
                                                   it
                                                   :class "identity small profile-gratitude"))))
               (:input :type "hidden" :name "subject" :value id)
               (:input :type "hidden" :name "next" :value (strcat *base-url* "/reputation"))
               (:table :class "post"
                (:tr
                  (:td (:textarea :cols "1000" :rows "4" :name "text"))
                  (:td
                    (:button :class "yes submit" :type "submit" :name "create" "Post"))))))))

        (:div :class "activity"
          (when groupid
            (str (group-activity-selection-html id name display (case type
                                                                      (:gratitude "reputation")
                                                                      (:offer "offers")
                                                                      (:request "requests")
                                                                      (t "activity")))))
          (str (profile-activity-items :id id
                                       :type type
                                       :members (when (or (string= display "all")
                                                          (string= display "members"))
                                                  members)
                                       :display display
                                       :page (aif (get-parameter "p") (parse-integer it) 0)))))

      :top (profile-top-html id)
      :right right
      :selected (case entity-type
                  (:person "people")
                  (:group "groups")))))
