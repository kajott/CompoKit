// script for adding a cables.gl background to the Wuhu slideviewer
//
// installation steps:
// - put this file into www_admin/slideviewer/custom.js
// - export the cables.gl patch as a single JavaScript file and put that into
//   www_admin/slideviewer/cables_background.js
// - (optional) in the patch, use the 'var set' / 'var get' ops to create a
//   string variable called '#slidetype'; this will receive one of the
//   following values:
//     - announcementSlide
//     - countdownSlide
//     - rotationSlide
//     - compoDisplaySlide-intro
//     - compoDisplaySlide-entry
//     - compoDisplaySlide-outro
//     - prizegivingSlide-intro
//     - prizegivingSlide-prizinator
//     - prizegivingSlide-entry

var lastSlideInfo = null;
var cablesPatch = null;
document.slideChangeNotify = function(slideInfo) {
    if (!slideInfo) return;
    lastSlideInfo = slideInfo;
    if (cablesPatch) {
        cablesPatch.setVariable("slidetype", slideInfo.slidetype);
    }
};

document.addEventListener("CABLES.jsLoaded", function(ev) {
    CABLES.EMBED.addPatch("slideviewerBackground", {
        "patch": CABLES.exportedPatch,
        "prefixAssetPath": "",
        "assetPath": "assets/",
        "glCanvasResizeToWindow": true,
        "onError": function (initiator,...args) { CABLES.logErrorConsole("[" + initiator + "]", ...args); },
        "onFinishedLoading": function(p) { cablesPatch = p; document.slideChangeNotify(lastSlideInfo); }
    });
});

var cablesJS = document.createElement("script");
cablesJS.src = "cables_background.js";
document.head.appendChild(cablesJS);
