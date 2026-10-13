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
    var lazy = showsPlaceholder(image) ? absolute(lazySource(image)) : null;
    // currentSrc, so srcset and <picture> give what is actually shown.
    var url = lazy || absolute(image.currentSrc || image.src);
    if (!url) return;
    // A lazy image not loaded yet has no natural size, and a placeholder's
    // size is not the picture's, so its box stands in.
    found.push({
      url: url,
      width: (!lazy && image.naturalWidth) || image.width,
      height: (!lazy && image.naturalHeight) || image.height,
      fromHead: false,
    });
  });
  return found.slice(0, MAX_PICTURES);
}

// Whether a lazy loader may still be holding the real picture back:
// nothing shown yet, an inline stand-in, or a blank pixel.
function showsPlaceholder(image) {
  var shown = image.currentSrc || image.src;
  return (
    shown === '' ||
    shown.indexOf('data:') === 0 ||
    (image.naturalWidth <= 1 && image.naturalHeight <= 1)
  );
}

// The attributes the common lazy loaders keep the real address in.
var LAZY_SOURCES = ['data-src', 'data-lazy-src', 'data-original'];
var LAZY_SOURCE_SETS = ['data-srcset', 'data-lazy-srcset'];

function lazySource(image) {
  for (var i = 0; i < LAZY_SOURCES.length; i++) {
    var value = image.getAttribute(LAZY_SOURCES[i]);
    if (value && value.trim()) return value;
  }
  for (var j = 0; j < LAZY_SOURCE_SETS.length; j++) {
    var set = image.getAttribute(LAZY_SOURCE_SETS[j]);
    if (set !== null) return largest(set);
  }
  return null;
}

// The largest picture a srcset offers, by its w or x descriptor.
function largest(srcset) {
  var best = null;
  // Split only at a comma followed by space: an address may hold a comma.
  srcset.split(/,\s+/).forEach(function (entry) {
    var parts = entry.trim().split(/\s+/);
    if (!parts[0]) return;
    var size = parseFloat(parts[1] || '1x') || 1;
    if (!best || size > best.size) best = { url: parts[0], size: size };
  });
  return best ? best.url : null;
}

var HrcekPreprocessing = function () {};

HrcekPreprocessing.prototype = {
  run: function (args) {
    args.completionFunction({ url: document.URL, title: document.title, pictures: pictures() });
  },
};

// The name Safari looks for.
var ExtensionPreprocessingJS = new HrcekPreprocessing();
