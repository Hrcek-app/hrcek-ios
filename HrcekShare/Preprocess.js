// Safari runs this in the shared page and hands its answer to the share
// extension (NSExtensionJavaScriptPreprocessingFile). Ranking and
// filtering happen in HrcekKit's PageCandidate, where they are tested.
var HEAD_SELECTORS = [
  'meta[property="og:image"]',
  'meta[property="og:image:secure_url"]',
  'meta[name="twitter:image"]',
  'meta[name="twitter:image:src"]',
  'link[rel="image_src"]',
  'meta[itemprop="image"]',
];

// Enough for any page worth choosing from, small enough to hand over.
var MAX_PICTURES = 200;

function absolute(raw) {
  if (!raw || !raw.trim()) return null;
  try {
    return new URL(raw, document.baseURI).href;
  } catch (e) {
    return null;
  }
}

function pictures() {
  var found = [];
  HEAD_SELECTORS.forEach(function (selector) {
    document.querySelectorAll(selector).forEach(function (node) {
      var url = absolute(node.getAttribute('content') || node.getAttribute('href'));
      if (url) found.push({ url: url, width: 0, height: 0, fromHead: true });
    });
  });
  Array.prototype.forEach.call(document.images, function (image) {
    // currentSrc, so srcset and <picture> give what is actually shown.
    var url = absolute(image.currentSrc || image.src);
    if (!url) return;
    // A lazy image not loaded yet has no natural size; its box stands in.
    found.push({
      url: url,
      width: image.naturalWidth || image.width,
      height: image.naturalHeight || image.height,
      fromHead: false,
    });
  });
  return found.slice(0, MAX_PICTURES);
}

var HrcekPreprocessing = function () {};

HrcekPreprocessing.prototype = {
  run: function (args) {
    args.completionFunction({ url: document.URL, title: document.title, pictures: pictures() });
  },
};

// The name Safari looks for.
var ExtensionPreprocessingJS = new HrcekPreprocessing();
