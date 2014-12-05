import Ember from 'ember';
import startApp from '../../helpers/start-app';
import activatePlayTime from '../../helpers/activate-play-time';
import visitChain from '../../helpers/visit-chain';

var App;

module('Acceptances - Play/Type', {
  setup: function() {
    App = startApp();
  },
  teardown: function() {
    Ember.run(App, 'destroy');
  }
});

test('play/type renders', function() {
  expect(8);
  //expect(9);

  activatePlayTime(App, false);

  visitChain(['/play/read', '/play/ok', '/play/type']);
  andThen(function() {
    var pNetstatus = find('p#netstatus');
    var sNetstatus = pNetstatus.find('span');
    var aHome = find('a#home');
    var pInstructions = find('p#instructions');
    var taText = find('textarea[name=text]');
    var bSend = find('button[name=send]');

    equal(pNetstatus.text(), 'Network status: ' + sNetstatus.text());

    equal(sNetstatus.text(), 'checking');
    equal(sNetstatus.attr('class'), 'checking');

    equal(aHome.text(), 'Home');
    equal(aHome.attr('href'), '/');

    equal(pInstructions.text(), 'Type the sentence as you remember it:');

    // TODO[search view]: make a view of the textarea, so it calls focus after render
    //ok(taText.is(':focus'));

    equal(bSend.text(), 'Send');
    equal(bSend.attr('type'), 'submit');
  });
});

test('navigate to home', function() {
  expect(2);

  activatePlayTime(App, false);

  visitChain(['/play/read', '/play/ok', '/play/type'], 'play.type');

  click('#home');
  andThen(function() {
    equal(currentRouteName(), 'index');
  });
});

test('coming from elsewhere than /play/ok redirects [from /]', function() {
  expect(1);

  activatePlayTime(App, false);

  visitChain(['/', '/play/type'], 'play.read');
});

test('coming from elsewhere than /play/ok redirects [from /play/read]', function() {
  expect(1);

  activatePlayTime(App, false);

  visitChain(['/', '/play/read/', '/play/type'], 'play.read');
});

function redirectTest(outButton, outRoute) {
  test('coming from elsewhere than /play/ok redirects [from /play/type then ' +
       outButton + ' then back]', function() {
    expect(2);

    activatePlayTime(App, false);

    visitChain(['/play/read/', '/play/ok', '/play/type']);
    click(outButton);
    andThen(function() {
      equal(currentRouteName(), outRoute);
    });
    andThen(function() {
      // This should be window.history.back();
      // But, dong so needs the router to use HashLocation for testing in browser,
      // which in turn makes the test server hang for an unknown reason.
      // So falling back to this for now.
      visit('/play/type');
    });
    andThen(function() {
      equal(currentRouteName(), 'play.read');
    });
  });
}

var outButtons = {'#home': 'index', 'button[name=send]': 'play.read'};

for (var outButton in outButtons) {
  redirectTest(outButton, outButtons[outButton]);
}
