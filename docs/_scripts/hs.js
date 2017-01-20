require(["gitbook"], function(gitbook) {
    gitbook.events.bind("start", function(e, config) {
        var code = config.hs.code;

        (function(d,s,i,r) {
            if (d.getElementById(i)){return;}
            var n=d.createElement(s),e=d.getElementsByTagName(s)[0];
            n.id=i;n.src='//js.hs-analytics.net/analytics/'+(Math.ceil(new Date()/r)*r)+'/'+ code +'.js';
            e.parentNode.insertBefore(n, e);
        })(document,"script","hs-analytics",300000);
    });

    // Notify pageview
    gitbook.events.bind("page.change", function() {
        if (typeof _hsq !== "undefined") {
            _hsq.push(['trackPageView'])
        }
    });
});
