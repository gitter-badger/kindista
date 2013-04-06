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

(defun signup-page (&key error 
                         invitation-id 
                         name 
                         host-name 
                         email 
                         password 
                         token 
                         invitation-email)
  (let ((code (or token (get-parameter "token")))
        (sender (or host-name (get-parameter "from")))
        (id (or invitation-id (get-parameter "id")))
        )
    (standard-page
      "Sign up"
      (html
        (when code 
          (htm 
            (:h2 "Please RSVP to your invitation. "
             (:br) "Your activation code is:  " (str code))))
        (:form :method "POST" :action "/signup" :id "signup"
          (:input :type "hidden" :name "token" :value code)
          (:input :type "hidden" :name "invitation-id" :value id)
          (:input :type "hidden" :name "host-name" :value sender)
          (:input :type "hidden" :name "invitation-email" :value (or invitation-email 
                                                                     (get-parameter "email")))
          (:h2 "Create an account") 
          (when error
            (flash error :error t))
          (:span
          (:label :for "name" "Full Name") 
          (:input :type "text" :name "name" :value name)) 
          (:br)
          (:label :for "email" "Email") 
          (:input :type "email" :name "email" :value (or email 
                                                         invitation-email
                                                         (get-parameter "email"))) 
          (:br)
          (:label :for "name" "Password") 
          (:input :type "password" :name "password" :value password) 
          (:p :class "fineprint" "By creating an account, you are agreeing to our "
            (:a :href "/terms" "Terms of Service") " and " (:a :href "/privacy" "Privacy Policy"))

          (:br)
          (:button :class "yes" :type "submit" "Sign up") 

          (:span "Have an account? " (:a :href "/login" "Log in")) 

          (:div :id "decline"
            (:p (:strong "Or decline the invitation so " 
                         (str sender) 
                         " can invite someone else.")))
          (:button :class "no" :name "decline" :type "submit" "Decline invitation")))
      :top (when (get-parameter "action")
             (welcome-bar
               (html
                 "If you want to do more than browse and search Kindista, you'll need to "
                 (:a :href "/signup" "create an account") ". Or, " (:a :href "/login" "log in")
                 " if you've already got one!")
               nil)))))

(defun decline-invitation (&key host-name id token email)
  (standard-page
    "Decline Invitation"
    (html
      (:h2 "Are you sure you want to decline your invitation from " (str host-name) "?")
      (:form :method "post" :action "/signup"
        (:input :type "hidden" :name "invitation-id" :value id)
        (:input :type "hidden" :name "token" :value token)
        (:input :type "hidden" :name "host-name" :value host-name)
        (:input :type "hidden" :name "invitation-email" :value email)
        (:button :class "no" :type "submit" :class "submit" :name "really-decline" "Decline")      
        (:button :class "link" :type "submit" :class "submit"  "No, I didn't mean it!")))))

(defun get-signup ()
  (with-user
    (cond 
      (*user* 
       (see-other "/home")) 
      ((or (not (get-parameter "id"))
           (not (get-parameter "token"))
           (not (get-parameter "from"))
           (not (get-parameter "email")))
       (flash "Kindista is by invitation only. You can only RSVP from a valid invitation email." :error t) 
       (see-other "/home"))
      (t 
       (signup-page)))))

(defun post-signup ()
  (with-user
    (let* ((userid (gethash (post-parameter "email") *email-index*))
           (id (parse-integer (post-parameter "invitation-id")))
           (invitation (db id))
           (host (getf (db invitation) :host))
           (host-name (post-parameter "host-name"))
           (new-id nil))
      (when *user* (reset-token-cookie)) 
      (cond

        ((post-parameter "decline")
         (decline-invitation :id id
                             :token (post-parameter "token")
                             :host-name (post-parameter "host-name")
                             :emails (post-parameter "invitation-email")))

        ((post-parameter "really-decline")
         (modify-db id 
                    :valid-until (get-universal-time))
         (flash (s+ "You have declined your invitation from " host-name "."))
         (see-other "/home"))

        ((not (and (post-parameter "invitation-id")
                   (post-parameter "token")))
         (flash "Kindista is by invitation only. You can only RSVP from a valid invitation email." :error t) 
         (see-other "/home"))

        ((not (eq (getf invitation :type) :invitation))
         (signup-page :error "You need a valid invitation ID. If you know anyone who is already on Kindista you should ask them for an invitation."
                      :name (post-parameter "name")
                      :emails (post-parameter "email")
                      :password (post-parameter "password")
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")))

        ((not (equal (getf invitation :recipient-email) 
                     (post-parameter "invitation-email")))
         (signup-page :error "The invitation ID you are using belongs to a different email address. 
Please use the correct email address or find someone you know on Kindista and request an invitation."
                      :name (post-parameter "name")
                      :emails (post-parameter "email")
                      :password (post-parameter "password")
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")))

        ((gethash (post-parameter "email") *email-index*)
         (signup-page :error "The email address you have entered already belongs to another Kindista member. Please try again, or contact us if this really is your email address."
                      :name (post-parameter "name")
                      :emails (post-parameter "email")
                      :password (post-parameter "password")
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")))

        ((< (getf invitation :valid-until) (get-universal-time))
         (signup-page :error "Your invitation has expired. Please contact the person who invited you to join Kindista and request another invitation."
                      :name (post-parameter "name")
                      :emails (post-parameter "email")
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :password (post-parameter "password")
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")))

        ((not (and (< 0 (length (post-parameter "name")))
                   (< 0 (length (post-parameter "email")))
                   (< 0 (length (post-parameter "password")))))
         (signup-page :error "All fields are required"
                      :name (post-parameter "name")
                      :emails (post-parameter "email")
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")  
                      :password (post-parameter "password")))

        ((> 8 (length (post-parameter "password")))
         (signup-page :error "Please use a strong password"
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")  
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :name (post-parameter "name")
                      :emails (post-parameter "email")))

        ((not (validate-name (post-parameter "name")))
         (signup-page :error "Please use your full name"
                      :invitation-id id
                      :invitation-email (post-parameter "invitation-email")  
                      :host-name (post-parameter "host-name")
                      :token (post-parameter "token")
                      :name (post-parameter "name")
                      :emails (post-parameter "email")
                      :password (post-parameter "password")))

        (t
           (setf new-id (create-person :name (post-parameter "name")
                                       :host host
                                       :emails (post-parameter "email")
                                       :password (post-parameter "password"))) 
           (setf (token-userid *token*) new-id) 
           (create-invitations :count 10 :host new-id) 
           (delete-invitation id) 
           (see-other "/home"))))))
