import Ember from 'ember';

import SessionMixin from 'gistr/mixins/session';
import EventControllerMixin from 'gistr/mixins/event-controller';
import draw from 'gistr/utils/draw';
import countTokens from 'gistr/utils/count-tokens';


export default Ember.Controller.extend(Ember.FSM.Stateful, SessionMixin, EventControllerMixin, {
  /*
   * Language and lifecycle utilities
   */
  lang: Ember.inject.service(),
  lifecycle: Ember.inject.service(),

  /*
   * Tree shaping parameters
   */
  shaping: Ember.inject.service(),
  pBranch: 0.8,

  /*
   * Writing parameters
   */
  minTokens: 10,

  /*
   * Timing parameters
   */
  readFactor: 1,     // multiplied by the number of tokens, gives seconds
  writeFactor: 5,    // multiplied by the number of tokens, gives seconds
  readDuration: function() {
    return this.get('readFactor') * this.get('sentenceTokensCount');
  }.property('readFactor', 'sentenceTokensCount'),
  writeDuration: function() {
    return this.get('writeFactor') * this.get('sentenceTokensCount');
  }.property('readFactor', 'sentenceTokensCount'),

  /*
   * Global progress and reset
   */
  streak: 0,
  resetStreak: function() {
    this.set('streak', 0);
  }.observes('lifecycle.currentState'),

  reset: function() {
    this.resetStreak();
    this.resetModels();
  },
  reloadTree: function() {
    return this.get('currentSentence.tree').then(function(tree) {
      return tree.reload();
    });
  },

  eventChecks: {
    /*
     * Lifecycle-related
     */
    'exp.training:lifecycle:just-completed-trials': {
      freeze: function(cycleValidation) {
        return (cycleValidation.state === 'exp.training' &&
                cycleValidation.completed.indexOf('completed-trials') !== -1);
      },
      check: function(frozen, cycleValidation) {
        return (!frozen &&
                cycleValidation.state === 'exp.training' &&
                cycleValidation.completed.indexOf('completed-trials') !== -1);
      }
    },
    'exp.doing:lifecycle:just-completed-trials': {
      freeze: function(cycleValidation) {
        return (cycleValidation.state === 'exp.doing' &&
                cycleValidation.completed.indexOf('completed-trials') !== -1);
      },
      check: function(frozen, cycleValidation) {
        return (!frozen &&
                cycleValidation.state === 'exp.doing' &&
                cycleValidation.completed.indexOf('completed-trials') !== -1);
      }
    },

    /*
     * Streak-related events
     */
    'playing:gain:new-credit': {
      freeze: function() {
        return this.get('currentProfile.suggestionCredit');
      },
      check: function(frozen) {
        return this.get('currentProfile.suggestionCredit') === frozen + 1;
      }
    },
    'exp.doing:rhythm:break': {
      freeze: function() {
        return this.get('streak');
      },
      check: function(frozen) {
        var streak = this.get('streak');
        return streak === frozen + 1 && streak !== 0 && streak % 10 === 0;
      }
    },
    'playing:rhythm:diff-break': {
      freeze: function() {
        return this.get('streak');
      },
      check: function(frozen) {
        var streak = this.get('streak');
        return streak === frozen + 1 && streak !== 0 && streak % 3 === 0;
      }
    },
    'playing:rhythm:exploration-break': {
      freeze: function() {
        return this.get('streak');
      },
      check: function(frozen) {
        var streak = this.get('streak');
        return streak === frozen + 1 && streak !== 0 && streak % 5 === 0;
      }
    }
  },

  loadInfos: function() {
    var self = this,
        lifecycle = this.get('lifecycle'),
        freezer = this.freezeEventChecks(lifecycle.validateState());

    return this.get('currentProfile').reload().then(function() {
      // Check events before attempting to transition to the cycle
      // since the freezer depends on the currentState
      var cycle = lifecycle.validateState();
      self.checkEvents(freezer, cycle);

      // Then transition state if possible
      if (cycle.isComplete) {
        lifecycle.transitionUp();
      }
    }).then(function() {
      var cycle = lifecycle.validateState(),
          events = self.get('events');

      // Should we inform?
      if (events.length > 0) {
        self.sendStateEvent('inform');
      } else if (!cycle.isComplete && cycle.actionRoutes.indexOf('play') === -1) {
        // We have no events but our cycle is incomplete,
        // and nothing in the play route can help advance it.
        self.sendStateEvent('inform');
      } else if (self.get('currentProfile.availableTreesBucket') === 0) {
        // No more sentences, even after our possible transition to the new state
        self.sendStateEvent('inform');
      } else {
        // Let the user read the instructions if we're there
        if (self.get('currentState') !== 'instructions') {
          self.sendStateEvent('task.read');
        }
      }
    });
  },

  /*
   * Current tree and sentence state and selection
   */
  currentSentence: null,
  sentenceTokensCount: function() {
    return countTokens(this.get('currentSentence.text'));
  }.property('currentSentence.text'),
  resetModels: function() {
    this.setProperties({
      currentSentence: null
    });
  },
  drawInTree: function(tree) {
    var branchesCount = tree.get('branchesCount'),
        targetBranchCount = this.get('shaping.targetBranchCount'),
        pBranch = this.get('pBranch'),
        root = tree.get('root'),
        tips = tree.get('tips'),
        effectiveTips = tips.underTips.length === 0 ?
            tips.overflownTips : tips.underTips;

    // If we only have a root, return fast
    if (tips.allTips.length === 0) { return root; }

    // Could we branch?
    if (branchesCount < targetBranchCount) {
      // Yes. Should we branch?
      if (Math.random() < pBranch) {
        // Yes, so return root
        return root;
      } else {
        // No. So draw an existing branch and a tip inside it
        // (hence the double `draw`), and return
        return this.store.find('sentence', draw(draw(effectiveTips)));
      }
    } else {
      // No. Draw from an existing branch.
      return this.store.find('sentence', draw(draw(effectiveTips)));
    }
  },
  selectModels: function() {
    // FIXME: evaluate if this can be moved to route, and break the cycle?
    var self = this, profile = this.get('currentProfile'),
        mothertongue = profile.get('mothertongue'),
        isOthertongue = mothertongue === this.get('lang.otherLanguage');

    var unshapedFilter = {
      // The tree is yet unseen
      untouched_by_profile: profile.get('id'),

      // In the proper language (this also assures the tree is not empty)
      root_language: isOthertongue ? this.get('lang.defaultLanguage') : mothertongue,
      with_other_mothertongue: isOthertongue,
      without_other_mothertongue: !isOthertongue,

      // Gistr bucket: experiment or game
      root_bucket: this.get('lifecycle.bucket'),

      // One random tree from the filtered list
      sample: 1,
    };

    var shapedFilter = Ember.setProperties(Ember.copy(unshapedFilter), {
      // Filter with proper shape (we want either branches_count or shortest_branch_depth
      // to be one less than these limits, but if unlucky enough to get a tree
      // that was just completed, we'll lengthen one of its branches)
      branches_count_lte: this.get('shaping.targetBranchCount'),
      shortest_branch_depth_lte: this.get('shaping.targetBranchDepth'),
    });

    return this.store.find('tree', shapedFilter).then(function(trees) {
      if (trees.length === 0) {
        // We're out of luck, all the available trees are already full! Still, get one of those
        return self.store.find('tree', unshapedFilter);
      } else {
        return trees;
      }
    }).then(function(trees) {
      // We got a tree! Draw from it
      return self.drawInTree(trees.objectAt(0));
    }).then(function(sentence) {
      // Finally, set the drawn sentence
      self.set('currentSentence', sentence);
    });
  },

  /*
   * Trial progress actions
   */
  actions: {
    'task.read': function() {
      this.sendStateEvent('task.read');
    },
    'task.distract': function() {
      this.sendStateEvent('task.distract');
    },
    'task.write.user': function() {
      this.sendStateEvent('task.write.user');
    },
    'task.timeout': function() {
      this.sendStateEvent('task.timeout');
    },
    processWriting: function() {
      this.incrementProperty('streak');
      this.sendStateEvent('task.write.process');
    },
    reset: function() {
      this.sendStateEvent('reset');
    }
  },

  /*
   * Trial progress FSM states and events
   */
  fsmStates: {
    initialState: 'instructions',
    knownStates: ['instructions', 'task.reading', 'task.distracting', 'task.writing.user',
                  'task.writing.processing', 'task.timedout', 'info', 'failed'],
    'task.reading': {
      willEnter: 'selectModels'
    }
  },
  fsmEvents: {
    'task.read': {
      transitions: {
        from: ['instructions', 'task.writing.processing', 'task.timedout', 'info'],
        to: 'task.reading'
      }
    },
    'task.distract': {
      transition: { 'task.reading': 'task.distracting' }
    },
    'task.write.user': {
      transition: { 'task.distracting': 'task.writing.user' }
    },
    'task.timeout': {
      transition: { 'task.writing.user': 'task.timedout' }
    },
    'task.write.process': {
      transition: {
        from: 'task.writing.user',
        to: 'task.writing.processing',
        enter: 'reloadTree',
        after: 'loadInfos'
      }
    },
    inform: {
      transition: {
        from: ['instructions', 'task.writing.processing'],
        to: 'info'
      }
    },
    reset: {
      transition: {
        from: '$all',
        to: '$initial',
        didEnter: 'reset'
      }
    }
  }
});
