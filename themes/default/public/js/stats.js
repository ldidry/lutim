function graph(stats_labels, stats_data, stats_total) {
    Morris.Line({
        // ID of the element in which to draw the chart.
        element: 'evol-holder',
        // Chart data records -- each entry in this array corresponds to a point on
        // the chart.
        data: stats_data,
        // The name of the data record attribute that contains x-values.
        xkey: 'day',
        // A list of names of data record attributes that contain y-values.
        ykeys: ['value'],
        // Labels for the ykeys -- will be displayed when you hover over the
        // chart.
        labels: ['Uploaded files'],
        xLabels: 'day',
        dateFormat: function(x) { return new Date(x).toLocaleDateString(); },
        xLabelFormat: function(x) { return x.toLocaleDateString(); }
    });
    Morris.Line({
        // ID of the element in which to draw the chart.
        element: 'total-holder',
        // Chart data records -- each entry in this array corresponds to a point on
        // the chart.
        data: stats_total,
        // The name of the data record attribute that contains x-values.
        xkey: 'day',
        // A list of names of data record attributes that contain y-values.
        ykeys: ['value'],
        // Labels for the ykeys -- will be displayed when you hover over the
        // chart.
        labels: ['Uploaded files'],
        xLabels: 'day',
        lineColors: ['red'],
        dateFormat: function(x) { return new Date(x).toLocaleDateString(); },
        xLabelFormat: function(x) { return x.toLocaleDateString(); }
    });
}
$(document).ready(function() {
    // Get the data
    var stats_labels = [], stats_data = [], stats_total = [];
    $("#stats-data thead th").each(function () {
        stats_labels.push($(this).html());
    });
    var i = 0;
    $("#stats-data tbody tr:first-child td").each(function () {
        var s = stats_labels[i++];
        s = s.replace(/([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})/, "$3-$2-$1");
        stats_data.push({ day: s, value: $(this).html()});
    });
    i = 0;
    $("#stats-data tbody tr:nth-child(2) td").each(function () {
        var s = stats_labels[i++];
        s = s.replace(/([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})/, "$3-$2-$1");
        stats_total.push({ day: s, value: $(this).html()});
    });

    // Hide the data
    $("#stats-data").hide();

    graph(stats_labels, stats_data, stats_total);

    $(window).resize(function() {
        $("#evol-holder").empty();
        $("#total-holder").empty();
        graph(stats_labels, stats_data, stats_total);
    });
    Morris.Donut(enabled_donut);
    Morris.Donut(disabled_donut);
});
