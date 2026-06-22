const CACHE_NAME='drama-tracker-v1';
const urlsToCache=['./index.html','./manifest.json'];

self.addEventListener('install',event=>{
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache=>cache.addAll(urlsToCache)).catch(()=>{})
  );
});

self.addEventListener('fetch',event=>{
  // Network-first strategy so cloud data and CDN assets always try fresh first
  event.respondWith(
    fetch(event.request).catch(()=>caches.match(event.request))
  );
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys().then(keys=>Promise.all(
      keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k))
    ))
  );
});
