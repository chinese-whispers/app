import Ember from 'ember';

import SessionMixin from 'gistr/mixins/session';
import EventfulMixin from 'gistr/mixins/eventful';
import splitEvent from 'gistr/utils/split-event';


export default Ember.Controller.extend(SessionMixin, EventfulMixin, {
  lang: Ember.inject.service(),

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
    this.resetEvents();
  },

  /*
   * Events, no checks used
   */
  eventChecks: {},
  eventFilter: function() { return true; },
  hasEvents: Ember.computed.notEmpty('events'),
  // TODO: move to mixin
  filterEvents: function(params) {
    var events = this.get('events');

    var optIncludes = function(part, param) {
      return part.includes(param) || Ember.isNone(param);
    };

    return events.filter(function(event) {
      var parts = splitEvent(event);
      return (optIncludes(parts.state, params.state) &&
              optIncludes(parts.type, params.type) &&
              optIncludes(parts.name, params.name));
    });
  },
  lifecycleEvent: function() {
    var events = this.filterEvents({ type: 'lifecycle' });
    if (events.length > 1) {
      throw new Error("Got more than one lifecycle event: " + events);
    }
    return events.objectAt(0);
  }.property('events'),
  hasTransitioned: function() {
    var lifecycleEvent = this.get('lifecycleEvent');
    // Note that if this is false, then hasStateWorkLeft will be false
    // i.e. with event but not transitioned => no work left
    return !Ember.isNone(lifecycleEvent) && this.get('lifecycle.currentState') !== splitEvent(lifecycleEvent).state;
  }.property('lifecycle.currentState', 'lifecycleEvent'),
  hasStateWorkLeft: function() {
    return this.get('lifecycle.validator.actionRoutes').contains('profile');
  }.property('lifecycle.validator.actionRoutes'),

  /*
   * Profile form fields, state, and upload
   */
  changeMothertongue: false,
  mothertongue: null,
  errors: null,
  isUploading: null,
  showOtherInfo: false,
  showBilingualInfo: false,
  resetInput: function() {
    this.setProperties({
      changeMothertongue: false,
      mothertongue: null,
      errors: null,
      isUploading: null,
      showOtherInfo: false,
      showBilingualInfo: false,
    });
  },
  uploadProfile: function() {
    var self = this, data = this.getProperties('mothertongue'),
        lifecycle = this.get('lifecycle'),
        profile = this.get('currentProfile'),
        forward;

    this.set('isUploading', true);
    this.set('justSaved', false);

    if (!profile) {
      // Create a profile
      profile = this.get('store').createRecord('profile', data);
    } else {
      // Update our existing profile
      profile.setProperties(data);
    }

    return profile.save().then(function() {
      self.set('justSaved', true);
      self.resetInput();

      // Transition lifecycle state if possible
      if (lifecycle.get('validator.isComplete')) {
        if (lifecycle.get('isInRegistering')) { forward = 'index'; }
        return lifecycle.transitionUp();
      }
    }).then(function() {
      if (!Ember.isNone(forward)) {
        self.transitionToRoute(forward);
      }
    }, function(error) {
      self.set('errors', error.errors);
    }).finally(function() {
      self.set('isUploading', false);
    });
  },

  /*
   * Profile completeness
   */
  profileValidationMap: {
    'registering': {
      'has-mothertongue': "Set your mothertongue"
    },
    'exp.training': {
      'tested-reading-span': "Test your reading-span below",
      'answered-questionnaire': "Fill in the general questionnaire below"
    }
  },
  profileErrors: function() {
    var lifecycle = this.get('lifecycle'),
        validationMap = this.get('profileValidationMap'),
        errors = [];

    var pendings = this.get('lifecycle.validator.pending'),
        state = this.get('lifecycle.validator.state');
    console.log(`[profile errors] state = ${state}`);
    console.log(`[profile errors] pendings = ${pendings}`);

    for (var pending of pendings) {
      if (lifecycle.get('items')[state][pending].route === 'profile') {
        errors.push(validationMap[state][pending]);
      }
    }

    return errors;
  }.property('lifecycle.validator.pending', 'lifecycle.validator.state'),
  isProfileIncomplete: Ember.computed.notEmpty('profileErrors'),
  profileMothertongueLabel: function() {
    var mothertongue = this.get('currentProfile.mothertongue');
    if (Ember.isNone(mothertongue)) { return; }
    return this.get('lang.supportedLanguages').filter(function(language) {
      return language.name === mothertongue;
    }).objectAt(0).label;
  }.property('currentProfile.mothertongue', 'lang.supportedLanguages'),

  /*
   * Profile actions
   */
  actions: {
    reset: function() {
      this.reset();
    },
    uploadProfile: function(callback) {
      callback(this.uploadProfile());
    },
    toggleOtherInfo: function() {
      this.toggleProperty('showOtherInfo');
      if (this.get('showOtherInfo')) {
        this.set('showBilingualInfo', false);
      }
    },
    toggleBilingualInfo: function() {
      this.toggleProperty('showBilingualInfo');
      if (this.get('showBilingualInfo')) {
        this.set('showOtherInfo', false);
      }
    },
    'lifecycle.update': function(event) {
      if (event.value) {
        if (this.get('lifecycle').isAtOrAfter('exp.training')) {
          console.log(`[profile] setting event ${event.name}`);
          this.pushEvent(this.get('lifecycle.currentState') + ':lifecycle:' + event.name);
        } else {
          console.log(`[profile] dropping event ${event.name} because of ` +
                      `unwanted lifecycle state ${this.get('lifecycle.currentState')}`);
        }
      }
    },
    changeMothertongue: function() {
      this.set('mothertongue', this.get('currentProfile.mothertongue'));
      this.set('changeMothertongue', true);
    },
    cancelChangeMothertongue: function() {
      this.set('mothertongue', null);
      this.set('changeMothertongue', false);
    }
  }
});
