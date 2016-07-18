function SimpleGraph(data, labels, canvas, settings) {

  this.settings = settings;

  setStyleDefaults(settings);

  this.dataSet  = new DataSet(data, labels, this.settings);
  this.grid     = new Grid(this.dataSet, this.settings);
  this.canvas   = canvas;

  this.draw = function() {
    if (this.settings.drawGrid) {
      this.grid.draw(this.canvas);
    }
    if (this.settings.yAxisCaption) {
      this.dataSet.labelYAxis(this.grid, this.canvas);
    }
    this.dataSet.labelXAxis(this.grid, this.canvas);
    this.dataSet.plot(this.grid, this.canvas);
  };

  this.replaceDataSet = function(dataSet) {
    this.dataSet = new DataSet(dataSet, dataSet.labels, this.settings);
    this.grid    = new Grid(this.dataSet, this.settings);
  };

  this.plotCurrentDataSet = function() {
    this.dataSet.plot(this.grid, this.canvas);
  };

  function setStyleDefaults(settings) {
    var targets = ["xAxisLabel", "yAxisLabel", "yAxisCaption", "hoverLabel", "hoverValue"];
    var types   = ["Color", "Font", "FontSize", "FontWeight"];
    jQuery.each(targets, function(index, target) {
      jQuery.each(types, function(index, type) {
        if (!settings[target + type]) {
          settings[target + type] = settings["label" + type];
        }
      });
    });

    settings.labelStyle = {
      font: settings.labelFontSize + '"' + settings.labelFont + '"',
      fill: settings.labelColor
    };

    jQuery.each(targets, function(index, target) {
      settings[target + "Style"] = {
        font: settings[target + "FontSize"] + ' ' + settings[target + "Font"],
        fill: settings[target + "Color"],
        "font-weight": settings[target + "FontWeight"]
      };
    });
  }
}

// Holds the data and labels to be plotted, provides methods for labelling the x and y axes,
// and for plotting it's own points. Each method requires a grid object for translating values to
// x,y pixel coordinates and a canvas object on which to draw.
function DataSet(data, labels, settings) {
  this.data     = data;
  this.labels   = labels;
  this.settings = settings;

  this.labelXAxis = function(grid, canvas) {
    (function(ds) {
      jQuery.each(ds.labels, function(i, label) {
        var x = grid.x(i);
        canvas.text(x + ds.settings.xAxisLabelOffset, ds.settings.height - 6, label).attr(ds.settings.xAxisLabelStyle);
      });
    })(this);
  };

  this.labelYAxis = function(grid, canvas) {
    // Legend
    canvas.rect(
      grid.leftEdge - (30 + this.settings.yAxisOffset), //TODO PARAM - Label Colum Width
      grid.topEdge,
      30, //TODO PARAM - Label Column Width
      grid.height
    ).attr({stroke: this.settings.lineColor, fill: this.settings.lineColor, opacity: 0.3}); //TODO PARAMS - legend border and fill style

    for (var i = 1, ii = (grid.rows); i < (ii - this.settings.lowerBound/2); i = i + 2) {
      var value = (ii - i)*2,
          y     = grid.y(value) + 4, // TODO: Value of 4 works for default dimensions, expect will need to scale
          x     = grid.leftEdge - (6 + this.settings.yAxisOffset);
      canvas.text(x, y, value).attr(this.settings.yAxisLabelStyle);
    }
    var caption = canvas.text(
      grid.leftEdge - (20 + this.settings.yAxisOffset),
      (grid.height/2) + (this.settings.yAxisCaption.length / 2),
      this.settings.yAxisCaption + " (" + this.settings.units + ")").attr(this.settings.yAxisCaptionStyle).rotate(270);
    // Increase the offset for the next caption (if any)
    this.settings.yAxisOffset = this.settings.yAxisOffset + 30;
  };

  this.plot = function(grid, canvas) {
    var line_path = canvas.path({
      stroke: this.settings.lineColor,
      "stroke-width": this.settings.lineWidth,
      "stroke-linejoin": this.settings.lineJoin
    });

    var fill_path = canvas.path({
      stroke: "none",
      fill: this.settings.fillColor,
      opacity: this.settings.fillOpacity
    }).moveTo(this.settings.leftGutter, this.settings.height - this.settings.bottomGutter);

    var bars  = canvas.group(),
        dots  = canvas.group(),
        cover = canvas.group();

    var hoverFrame = dots.rect(10, 10, 100, 40, 5).attr({
      fill: "#fff", stroke: "#474747", "stroke-width": 2}).hide(); //TODO PARAM - fill colour, border colour, border width
    var hoverText = [];
    hoverText[0] = canvas.text(60, 25, "").attr(this.settings.hoverValueStyle).hide();
    hoverText[1] = canvas.text(60, 40, "").attr(this.settings.hoverLabelStyle).hide();

    // Plot the points
    (function(dataSet) {
      jQuery.each(dataSet.data, function(i, value) {
        var y = grid.y(value),
            x = grid.x(i),
            label = dataSet.labels ? dataSet.labels[i]  : " ";

        if (dataSet.settings.drawPoints) {
          var dot = dots.circle(x, y, dataSet.settings.pointRadius).attr({fill: dataSet.settings.pointColor, stroke: dataSet.settings.pointColor});
        }
        if (dataSet.settings.drawBars) {
          bars.rect(x + dataSet.settings.barOffset, y, dataSet.settings.barWidth, (dataSet.settings.height - dataSet.settings.bottomGutter) - y).attr({fill: dataSet.settings.barColor, stroke: "none"});
        }
        if (dataSet.settings.drawLine) {
          line_path[i == 0 ? "moveTo" : "cplineTo"](x, y, 5);
        }
        if (dataSet.settings.fillUnderLine) {
          fill_path[i == 0 ? "lineTo" : "cplineTo"](x, y, 5);
        }
        if (dataSet.settings.addHover) {
          var rect = canvas.rect(x - 50, y - 50, 100, 100).attr({stroke: "none", fill: "#fff", opacity: 0}); //TODO PARAM - hover target width / height
          jQuery(rect[0]).hover( function() {
            jQuery.fn.simplegraph.hoverIn(canvas, value, label, x, y, hoverFrame, hoverText, dot, dataSet.settings);
          },
          function() {
            jQuery.fn.simplegraph.hoverOut(canvas, hoverFrame, hoverText, dot, dataSet.settings);
          });
        }
      });
    })(this);

    if (this.settings.fillUnderLine) {
      fill_path.lineTo(grid.x(this.data.length - 1), this.settings.height - this.settings.bottomGutter).andClose();
    }
    hoverFrame.toFront();
  };
}

// Holds the dimensions of the grid, and provides methods to convert values into x,y
// pixel coordinates. Also, provides a method to draw a grid on a supplied canvas.
function Grid(dataSet, settings) {
  this.dataSet = dataSet;
  this.settings = settings;

  this.calculateMaxYAxis = function() {
    var max = Math.max.apply(Math, this.dataSet.data),
    maxOveride = this.settings.minYAxisValue;
    if (maxOveride && maxOveride > max) {
      max = maxOveride;
    }
    return max;
  };

  this.setYAxis = function() {
    this.height        = this.settings.height - this.settings.topGutter - this.settings.bottomGutter;
    this.maxValueYAxis = this.calculateMaxYAxis();
    this.Y             = this.height / (this.maxValueYAxis - this.settings.lowerBound);
  };

  this.setXAxis = function() {
    this.X = (this.settings.width - this.settings.leftGutter) / (this.dataSet.data.length - 0.4);
  };

  this.setDimensions = function() {
    this.leftEdge = this.settings.leftGutter;
    this.topEdge  = this.settings.topGutter;
    this.width    = this.settings.width - this.settings.leftGutter - this.X;
    this.columns  = this.dataSet.data.length - 1;
    this.rows     = (this.maxValueYAxis - this.settings.lowerBound) / 2; //TODO PARAM - steps per row
  };

  this.draw = function(canvas) {
    canvas.drawGrid(
      this.leftEdge,
      this.topEdge,
      this.width,
      this.height,
      this.columns,
      this.rows,
      this.settings.gridBorderColor
    );
  };

  this.x = function(value) {
    return this.settings.leftGutter + this.X * value;
  };

  this.y = function(value) {
    return this.settings.height - this.settings.bottomGutter - this.Y * (value - this.settings.lowerBound);
  };

  this.setYAxis();
  this.setXAxis();
  this.setDimensions();

};

(function($) {

  //- required to implement hover function
  var isLabelVisible;
  var leaveTimer;

  $.fn.simplegraph = function(data, labels, options) {
    var settings = $.extend({}, $.fn.simplegraph.defaults, options);
    setPenColor(settings);

    return this.each( function() {
      var canvas = Raphael(this, settings.width, settings.height);
      var simplegraph = new SimpleGraph(data, labels, canvas, settings);

      simplegraph.draw();

      // Stash simplegraph object away for future reference
      $.data(this, "simplegraph", simplegraph);
    });
  };

  // Plot another set of values on an existing graph, use it like this:
  //   $("#target").simplegraph(data, labels).simplegraph_more(moreData);
  $.fn.simplegraph_more = function(data, options) {
    return this.each( function() {
      var sg = $.data(this, "simplegraph");
      sg.dataSet = new DataSet(data, sg.dataSet.labels, sg.settings);
      sg.settings.penColor = options.penColor;
      setPenColor(sg.settings);
      sg.settings = $.extend(sg.settings, options);
      sg.grid  = new Grid(sg.dataSet, sg.settings);
      sg.dataSet.labelYAxis(sg.grid, sg.canvas);
      sg.dataSet.plot(sg.grid, sg.canvas);
    });
  };

  // Public

  $.fn.simplegraph.defaults = {
    drawGrid: false,
    units: "",
    // Dimensions
    width: 600,
    height: 250,
    leftGutter: 30,
    bottomGutter: 20,
    topGutter: 20,
    // Label Style
    labelColor: "#000",
    labelFont: "Helvetica",
    labelFontSize: "10px",
    labelFontWeight: "normal",
    // Grid Style
    gridBorderColor: "#ccc",
    // -- Y Axis Captions
    yAxisOffset: 0,
    // -- Y Axis Captions
    xAxisLabelOffset: 0,
    // Graph Style
    // -- Points
    drawPoints: false,
    pointColor: "#000",
    pointRadius: 3,
    activePointRadius: 5,
    // -- Line
    drawLine: true,
    lineColor: "#000",
    lineWidth: 3,
    lineJoin: "round",
    // -- Bars
    drawBars: false,
    barColor: "#000",
    barWidth: 10,
    barOffset: 0,
    // -- Fill
    fillUnderLine: false,
    fillColor: "#000",
    fillOpacity: 0.2,
    // -- Hover
    addHover: true,
    // Calculations
    lowerBound: 0
  };

  // Default hoverIn callback, this is public and as such can be overwritten. You can write your
  // own call back with the same signature if you want different behaviour.
  $.fn.simplegraph.hoverIn = function(canvas, value, label, x, y, frame, hoverLabel, dot, settings) {
    clearTimeout(leaveTimer);
    var newcoord = {x: x * 1 + 7.5, y: y - 19};
    if (newcoord.x + 100 > settings.width) {
        newcoord.x -= 114;
    }
    hoverLabel[0].attr({text: value}).show().animate({x : newcoord.x + 50, y : newcoord.y + 15}, (isLabelVisible ? 100 : 0));
    hoverLabel[1].attr({text: label}).show().animate({x : newcoord.x + 50, y : newcoord.y + 30}, (isLabelVisible ? 100 : 0));
    frame.show().animate({x: newcoord.x, y: newcoord.y}, (isLabelVisible ? 100 : 0));
    if (settings.drawPoints) {
      dot.attr("r", settings.activePointRadius);
    }
    isLabelVisible = true;
    canvas.safari();
  };

  // Default hoverOut callback, this is public and as such can be overwritten. You can write your
  // own call back with the same signature if you want different behaviour.
  $.fn.simplegraph.hoverOut = function(canvas, frame, label, dot, settings) {
    if (settings.drawPoints) {
      dot.attr("r", settings.pointRadius);
    }
    canvas.safari();
    leaveTimer = setTimeout(function () {
      isLabelVisible = false;
        frame.hide();
        label[0].hide();
        label[1].hide();
        canvas.safari();
    }, 1);
  };

  // Private

  function setPenColor(settings) {
    if (settings.penColor) {
      settings.lineColor  = settings.penColor;
      settings.pointColor = settings.penColor;
      settings.fillColor  = settings.penColor;
      settings.barColor   = settings.penColor;
    }
  }

})(jQuery);
