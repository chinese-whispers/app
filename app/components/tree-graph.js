import Ember from 'ember';
var d3 = window.d3;

import SessionMixin from 'gistr/mixins/session';
import distance from 'gistr/utils/levenshtein';
import graphPath from 'gistr/utils/graph-path';


export default Ember.Component.extend(SessionMixin, {
  /*
   * Component options
   */
  tagName: 'div',
  classNameBindings: ['overview:graph-overview:graph-detail'],

  /*
   * Utility properties
   */
  maxTreeDepth: 10,   // FIXME: move this to server meta
  maxTreeBreadth: 5,  // FIXME: move this to server meta
  detail: Ember.computed.not('overview'),

  /*
   * Resizing
   */
  resizeEvent: function() {
    var name = 'resize.tree-graph-', tree = this.get('tree');
    name += this.get('overview') ? 'overview-' : 'detail-';
    name += `tree-${tree.id}`;
    return name;
  }.property('overview', 'tree'),
  resizeT0: null,

  /*
   * Initialize and close drawing
   */
  initDrawing: function() {
    var self = this,
        depth = this.get('tree.depth'),
        breadth = this.get('tree.breadth'),
        element = this.get('element'),
        $element = Ember.$(element),
        $parent = Ember.$(this.get('element')).parent();

    var pwidth = $parent.width(),
        pheight = $parent.height();

    var scale = this.get("overview") ? 0.5 : 1,
        wScale = (depth + 1) / (this.get('maxTreeDepth') + 1),
        hScale = (breadth + 1) / (this.get('maxTreeBreadth') + 1);

    $element.css("height", pheight * hScale);

    var margin = {
      top: pheight / ((this.get('maxTreeBreadth') + 1) * 2),
      right: pwidth / ((this.get('maxTreeDepth') + 1) * 2),
      bottom: pheight / ((this.get('maxTreeBreadth') + 1) * 2),
      left: pwidth / ((this.get('maxTreeDepth') + 1) * 2)
    };

    var width = pwidth * wScale - margin.left - margin.right,
        height = pheight * hScale - margin.top - margin.bottom;

    var svg = d3.select(element).append("svg");

    var g = svg.attr("width", pwidth)
        .attr("height", pheight * hScale)
      .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + "), scale(" + scale + ")");

    Ember.$(window).on(this.get('resizeEvent'), function() {
      if(self.get('resizeT0')) {
        Ember.run.cancel(self.get('resizeT0'));
      }
      self.set('resizeT0', Ember.run.later(null, function() {
        pwidth = $parent.width();
        var width = pwidth * wScale - margin.left - margin.right,
            height = pheight * hScale - margin.top - margin.bottom;

        svg.attr("width", pwidth)
            .attr("height", pheight * hScale);

        self.draw(g, width / scale, height / scale);
      }, 200));
    });

    this.draw(g, width / scale, height / scale);
  }.on('didInsertElement'),
  closeDrawing: function() {
    Ember.$(window).off(this.get('resizeEvent'));
  }.on('willDestroyElement'),

  /*
   * Actual drawing core
   */
  draw: function(g, width, height) {
    var graph = this.get('tree.graph');

    var layout = d3.layout.tree()
        .size([height, width])  // inverted height/width to have a horizontal tree
        .sort(function(a, b) {
          // Proxy creation order by sentenceId
          return a.sentenceId - b.sentenceId;
        });

    var layoutNodes = layout.nodes(graph.root),
        layoutLinks = layout.links(layoutNodes);

    var diagonal = d3.svg.diagonal()
        .projection(function(d) { return [d.y, d.x]; });

    var link = g.selectAll(".link")
        .data(layoutLinks)
        .attr("d", diagonal)
      .enter().append("path")
        .attr("class", "link")
        .attr("d", diagonal);

    var node = g.selectAll(".node")
        .data(layoutNodes)
        .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
      .enter().append("g")
        .attr("class", "node")
        .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });

    node.append("circle")
        .attr("r", 8)
        .classed("root", function(d) { return Ember.isNone(d.parent); });

    if (this.get('detail')) {
      this.numberSentences(node);
      this.styleLinks(link);
      this.markOwnSentences(node);
      this.setMouseListeners(node, link);
    }
  },
  styleLinks: function(link) {
    var scale01 = function(a) { return Math.atan(a / 30) * 2 / Math.PI; };
    //var color = d3.scale.linear()
        //.domain([0, 1])
        //.range(["grey", "red"]);

    return this.get('tree.sentences').then(function(sentences) {
      var sentenceMap = {};
      sentences.forEach(function(sentence) {
        sentenceMap[sentence.get('id')] = sentence;
      });

      link.style("stroke-dasharray", function(d) {
            var source = sentenceMap[d.source.sentenceId],
                target = sentenceMap[d.target.sentenceId];
            return source.get('text').localeCompare(target.get('text')) === 0 ? "3px" : "0";
          })
          .style("stroke-width", function(d) {
            var source = sentenceMap[d.source.sentenceId],
                target = sentenceMap[d.target.sentenceId],
                diff = distance(source.get('text'), target.get('text'));
            return String(1 + 4 * scale01(diff)) + "px";
          //})
          //.style("stroke", function(d) {
            //var source = sentenceMap[d.source.sentenceId],
                //target = sentenceMap[d.target.sentenceId],
                //diff = distance(source.get('text'), target.get('text'));
            //return color(scale01(diff));
          });
    });
  },
  numberSentences: function(node) {
    node.append("text")
        .attr("dx", 0)
        .attr("dy", "-1.2em")
        .text(function(d) { return `${d.sentenceId}`; });
  },
  markOwnSentences: function(node) {
    // Find own sentences
    var profile = this.get('currentProfile');
    return this.get('tree.sentences').then(function(sentences) {
      var sentenceProfileMap = {};
      sentences.forEach(function(sentence) {
        sentenceProfileMap[sentence.get('id')] = sentence.get('profile');
      });
      return Ember.RSVP.hash(sentenceProfileMap);
    }).then(function(sentenceProfileMap) {
      node.selectAll("circle")
          .classed("own", function(d) {
            return sentenceProfileMap[d.sentenceId] === profile;
          });
    });
  },
  setMouseListeners: function(node, link) {
    var self = this;
    // Set event listeners
    node.selectAll("circle")
        .on("mouseover", function(d) {
          d3.select(this).attr("r", 10);
          self.sendAction("hover", self.store.find('sentence', d.sentenceId));
        })
        .on("mouseout", function(/*d*/) {
          d3.select(this).attr("r", 8);
          self.sendAction("hover", null);
        })
        .on("click", function(/*d*/) {
          var selection = node.selectAll(".selected"),
              el = d3.select(this);

          if (selection.size() < 2) {
            el.classed("selected", !el.classed("selected"));
          } else {
            el.classed("selected", false);
          }

          // Update selection
          selection = node.selectAll(".selected");
          var selectedData = [], path;
          selection.each(function(d) {
            selectedData.push(d);
          });
          selectedData = selectedData.sortBy('sentenceId');

          if (selectedData.length === 2) {
            path = graphPath(selectedData.objectAt(0), selectedData.objectAt(1));
            link.classed("through", function(d) {
              return path.contains(d.source) && path.contains(d.target);
            });
          } else {
            link.classed("through", false);
          }

          // Send selection to upper powers
          var start, end;
          if (selectedData.length > 0) { start = self.store.find('sentence', selectedData.objectAt(0).sentenceId); }
          if (selectedData.length > 1) { end = self.store.find('sentence', selectedData.objectAt(1).sentenceId); }
          Ember.RSVP.hash({
            start: start,
            end: end,
            path: Ember.isNone(path) ? null : Ember.RSVP.all(path.map(function(d) {
              return self.store.find('sentence', d.sentenceId);
            }))
          }).then(function(hash) {
            self.sendAction("select", hash);
          });
        });
  }
});