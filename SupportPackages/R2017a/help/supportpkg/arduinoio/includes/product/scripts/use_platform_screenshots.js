/*global window, $, document */

function usePlatformScreenshots() {
    "use strict";
    var ua = window.navigator.userAgent,
        platformPattern = /\/examples\/(\w+)\/(glnxa64|maci64|win64)\//,
        platform = 'win64';
    if (ua.match(/Linux/)) {
        platform = 'glnxa64';
    } else if (ua.match(/Macintosh/)) {
        platform = 'maci64';
    }
    $('img').each(function () {
        var img = $(this),
            src = img.attr('src');
        src = src.replace(platformPattern, '/examples/$1/' + platform + '/');
        img.attr('src', src);
    });

}

$(document).ready(usePlatformScreenshots);
