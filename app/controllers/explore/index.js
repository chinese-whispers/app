import Ember from 'ember';

import SessionMixin from 'gistr/mixins/session';


export default Ember.Controller.extend(SessionMixin, {
  lifecycle: Ember.inject.service(),
  isStaffOrInPlaying: Ember.computed.or('currentUser.isStaff', 'lifecycle.isInPlaying')
});
