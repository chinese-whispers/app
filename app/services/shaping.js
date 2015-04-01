import Ember from 'ember';


export default Ember.Service.extend({
  serverMeta: Ember.inject.service(),

  targetBranchCount: null,
  targetBranchLength: null,

  _populationPromise: null,
  populate: function() {
    var self = this,
        _populationPromise = this.get('_populationPromise');

    if (!Ember.isNone(_populationPromise)) {
      return _populationPromise;
    }

    _populationPromise = this.get('serverMeta').populate().then(function(serverMeta) {
      var data = serverMeta.get('data');
      self.set('targetBranchCount', data.target_branch_count);
      self.set('targetBranchLength', data.target_branch_length);
      return self;
    });

    this.set('_populationPromise', _populationPromise);
    return _populationPromise;
  }
});
