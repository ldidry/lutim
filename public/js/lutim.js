$('document').ready(function() {
    $('.jsonly').show();
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
});
