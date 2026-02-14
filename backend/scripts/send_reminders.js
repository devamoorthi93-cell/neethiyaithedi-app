const admin = require('firebase-admin');
const moment = require('moment');

// Initialize Firebase Admin
// The service account key will be provided via environment variable in GitHub Actions
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const fcm = admin.messaging();

async function sendFeeReminders() {
    console.log('Starting automated fee reminder process...');

    const currentMonth = moment().format('YYYY-MM');
    const currentMonthFormatted = moment().format('MMMM YYYY');
    const dayOfMonth = moment().date();
    const isOverdue = dayOfMonth > 10;
    const tamilMonth = getTamilMonth(moment().month());

    console.log(`Date: ${moment().format('YYYY-MM-DD')}, Day: ${dayOfMonth}, Overdue: ${isOverdue}`);

    try {
        // 1. Fetch all members
        const usersSnapshot = await db.collection('users')
            .where('role', '==', 'member')
            .get();

        const unpaidMembers = [];
        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            // Check if user has NOT paid for the current month and has an FCM token
            if (userData.lastPaymentMonth !== currentMonth && userData.fcmToken) {
                unpaidMembers.push({
                    uid: doc.id,
                    name: userData.name,
                    fcmToken: userData.fcmToken,
                });
            }
        });

        if (unpaidMembers.length === 0) {
            console.log('No unpaid members with active notification tokens found.');
            return;
        }

        console.log(`Found ${unpaidMembers.length} unpaid members. Preparing notifications...`);

        // 2. Prepare bilingual content
        let title, body;
        if (isOverdue) {
            title = '⚠️ சந்தா செலுத்த காலதாமதம் | Overdue Notice';
            body = `${tamilMonth} மாதத்திற்கான உங்கள் ₹100 சந்தாவை இன்னும் செலுத்தவில்லை. தயவுசெய்து விரைந்து செலுத்தவும்.\n\n` +
                `Your monthly fee for ${currentMonthFormatted} is overdue. Please pay ₹100 immediately to maintain your active status.`;
        } else if (dayOfMonth === 1) {
            title = '💰 புதிய மாத சந்தா | New Month Fee';
            body = `${tamilMonth} மாதம் தொடங்கிவிட்டது! இந்த மாதத்திற்கான ₹100 சந்தாவை 10-ம் தேதிக்குள் செலுத்தவும்.\n\n` +
                `A new month has begun! Please pay your monthly fee of ₹100 for ${currentMonthFormatted} by the 10th.`;
        } else {
            title = '🔔 சந்தா நினைவூட்டல் | Fee Reminder';
            body = `${tamilMonth} மாதத்திற்கான உங்கள் ₹100 சந்தாவை 10-ம் தேதிக்குள் செலுத்த நினைவூட்டுகிறோம்.\n\n` +
                `Reminder to pay your monthly fee of ₹100 for ${currentMonthFormatted} by the 10th.`;
        }

        // 3. Send notifications in batches
        const tokens = unpaidMembers.map(m => m.fcmToken);

        // sendEachForMulticast handles up to 500 tokens
        const response = await fcm.sendEachForMulticast({
            tokens: tokens,
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: 'FEE_REMINDER',
                month: currentMonth,
                isOverdue: String(isOverdue),
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'fee_reminders',
                    priority: 'high',
                },
            },
        });

        console.log(`Successfully sent ${response.successCount} notifications.`);
        console.log(`Failed to send ${response.failureCount} notifications.`);

        // 4. Log the result to Firestore
        await db.collection('notifications_log').add({
            type: 'AUTOMATED_FEE_REMINDER',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            totalRecipients: tokens.length,
            successCount: response.successCount,
            failureCount: response.failureCount,
            isOverdue: isOverdue,
            month: currentMonth,
            source: 'GitHub_Actions'
        });

    } catch (error) {
        console.error('CRITICAL ERROR in reminder process:', error);
        process.exit(1);
    }
}

function getTamilMonth(monthIndex) {
    const tamilMonths = [
        'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
        'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்'
    ];
    return tamilMonths[monthIndex];
}

// Execute the process
sendFeeReminders().then(() => {
    console.log('Reminder process completed.');
    process.exit(0);
});
