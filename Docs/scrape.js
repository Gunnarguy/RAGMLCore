const https = require('https');

const urls = [
  'https://developer.apple.com/documentation/foundationmodels',
  'https://developer.apple.com/documentation/foundationmodels/languagemodelsession',
  'https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel'
];

urls.forEach(url => {
  https.get(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    }
  }, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      const name = url.split('/').pop();
      console.log(`Downloaded ${name}: ${data.length} bytes`);
    });
  });
});
