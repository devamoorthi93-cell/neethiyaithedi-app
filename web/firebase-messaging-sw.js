importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: "AIzaSyB_U6U87roMFqkNZPK4ueopuNw7lS9edFM",
    authDomain: "neethiyaithedi-a2640.firebaseapp.com",
    projectId: "neethiyaithedi-a2640",
    storageBucket: "neethiyaithedi-a2640.firebasestorage.app",
    messagingSenderId: "1040367289333",
    appId: "1:1040367289333:web:bb0bd07507ad72d24796bc",
    measurementId: "G-37FV9PTL0W"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/favicon.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
