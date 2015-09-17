function addItem(item) {
    var files = localStorage.getItem('images');
    if (files === null) {
        files = new Array();
    } else {
        files = JSON.parse(files);
    }
    files.push(item);
    localStorage.setItem('images', JSON.stringify(files));
}
function share(url) {
    new MozActivity({
        name: 'share',
        data: {
            type: 'url',
            number: 1,
            url: url
        }
    });
}
function evaluateCopyAll() {
    setTimeout(function() {
        if ($('.view-link-input').length === 0) {
            $('#copy-all').parent().remove();
        }
    }, 5);
}
window.onload = function() {
    if (navigator.mozSetMessageHandler !== undefined) {
        navigator.mozSetMessageHandler('activity', function handler(activityRequest) {
            var activityName = activityRequest.source.name;
            if (activityName == 'share') {
                activity = activityRequest;
                blob = activity.source.data.blobs[0];
                fileUpload(blob);
            }
        });
    }
};
$('document').ready(function() {
    $('.jsonly').show();
    $('.input-group-addon.jsonly').css('display', 'table-cell');
    // Are we in a mozilla navigator? (well, are we in a navigator which can handle webapps?)
    if (navigator.mozApps !== undefined) {
        var installCheck = navigator.mozApps.checkInstalled(manifestUrl);
        installCheck.onsuccess = function() {
            if(installCheck.result === null) {
                var button = $('#install-app');
                // Show app install button when app is not installed
                button.css('display','inline-block');
                button.click(function() {
                    var request = window.navigator.mozApps.install(manifestUrl);
                    request.onsuccess = function () {
                        // Save the App object that is returned
                        var appRecord = this.result;
                        button.css('display','none');
                    };
                    request.onerror = function () {
                        // Display the error information from the DOMError object
                        alert('Install failed, error: ' + this.error.name);
                    };
                });
            }
        }
    }
    var firstview = ($('#first-view').prop('checked')) ? 1 : 0;
    var deleteday = ($('#delete-day').prop('checked')) ? 1 : 0;

    bindddz(firstview, deleteday);

    $('#file-url-button').on('click', upload_url);
    $('#lutim-file-url').keydown( function(e) {
        var key = e.charCode ? e.charCode : e.keyCode ? e.keyCode : 0;
        if(key == 13) {
            e.preventDefault();
            upload_url();
        }
    });
});
