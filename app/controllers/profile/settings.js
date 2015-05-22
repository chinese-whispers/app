import Ember from 'ember';

import SessionMixin from 'gistr/mixins/session';


export default Ember.Controller.extend(SessionMixin, {
  /*
   * Global state and reset
   */
  justSaved: false,
  watchSaved: function() {
    if (this.get('justSaved')) {
      Ember.run.later(this, function() {
        this.set('justSaved', false);
      }, 2000);
    }
  }.observes('justSaved'),
  reset: function() {
    this.resetInput();
    this.setProperties({
      justSaved: null,
    });
  },

  /*
   * Profile form fields, state, and upload
   */
  username: null,
  errors: null,
  isUploading: null,
  resetInput: function() {
    this.setProperties({
      username: this.get('currentUser.username'),
      errors: null,
      isUploading: null,
    });
    Ember.$('input').blur();
  },
  uploadUser: function() {
    var self = this, data = this.getProperties('username'),
        user = this.get('currentUser');

    this.set('isUploading', true);
    this.set('justSaved', false);

    return user.setProperties(data).save().then(function() {
      self.set('justSaved', true);
      self.resetInput();
    }, function(error) {
      self.set('errors', error.errors);
    }).finally(function() {
      self.set('isUploading', false);
    });
  },
  actions: {
    reset: function() {
      this.reset();
    },
    uploadUser: function(callback) {
      callback(this.uploadUser());
    }
  }
});