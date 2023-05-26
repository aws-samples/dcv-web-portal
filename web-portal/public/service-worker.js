/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */

self.addEventListener('install', event => {
    self.skipWaiting();
});

self.addEventListener('activate', event => {
});

self.addEventListener('fetch', event => {
    event.respondWith(fetch(event.request));
});