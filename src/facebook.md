https://developers.facebook.com/docs/facebook-login/permissions/v2.3
https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow
[x] Save FB token and expriation to kindista user object
[x] display whether or not there is a valid facebook token on k settings page
[x] enable users to unlink kindista w/ facebook

#Settings Page
 - don't allow link to facebook when pending?
 - List of permissions possible to select:
   - publish_actions
    - user_managed_groups, manage_pages, publish_pages (under-development)
    - read_custom_friendslist? (maybe)
    - email - "we will only contact you via your 'primary email address',
               this permission helps us ensure that your kindista account
               is associated with the correct facebook account."
 [ ] handle when people uninstall app from facebook
 https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow#logout

#Privacy setting

#List of friends using Kindista app
https://graph.facebook.com/{user-id}/friends?fields=installed

#Offers and Requests
https://developers.facebook.com/docs/sharing/reference/share-dialog
https://developers.facebook.com/docs/graph-api/using-graph-api/v2.3
https://developers.facebook.com/docs/sharing/opengraph/custom
https://developers.facebook.com/docs/sharing/opengraph/using-actions
[ ] create facebook story w/ new inventory items
    - get caption to display correctly
[ ] in the inventory item, indicate whether the item has been posted to FB
[ ] edit facebook story when editing inventory item
[ ] delete facebook story when deleting inventory item
[ ] if facebook token has expired/deactivatd, invite user to get a new one and let them know that if they don't, changes will not be reflected on FB

#Gratitude


#Review
[ ] take screen shots
https://developers.facebook.com/docs/apps/review
[ ] submit to facebook for review

- Remove admin restriction for :share-url in inventory-activity-item

#Group-Accounts
- permissions:
    manage_pages, publish_pages

#Invite Friends?
